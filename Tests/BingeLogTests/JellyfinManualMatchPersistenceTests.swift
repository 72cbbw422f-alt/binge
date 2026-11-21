import Foundation
import XCTest
@testable import BingeLog

final class JellyfinManualMatchPersistenceTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "BingeLog.JellyfinManualMatchPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    func testMappingIsWrittenBeforePersistenceClosureRuns() throws {
        let defaults = makeDefaults()
        var persistenceWasCalled = false

        try JellyfinManualMatchPersistence.save(
            tmdbID: 123,
            for: "https://media.example.com|item-1",
            in: defaults
        ) {
            let matches = defaults.dictionary(
                forKey: JellyfinManualMatchPersistence.defaultsKey
            ) as? [String: Int]
            XCTAssertEqual(matches?["https://media.example.com|item-1"], 123)
            persistenceWasCalled = true
        }

        XCTAssertTrue(persistenceWasCalled)
    }

    func testFailedPersistenceRestoresPreviousMappingAndKeepsOtherServers() {
        let defaults = makeDefaults()
        let key = "https://media.example.com|item-1"
        defaults.set([
            key: 111,
            "https://other.example.com|item-1": 222
        ], forKey: JellyfinManualMatchPersistence.defaultsKey)

        XCTAssertThrowsError(
            try JellyfinManualMatchPersistence.save(
                tmdbID: 333,
                for: key,
                in: defaults
            ) {
                throw NSError(domain: "PersistenceFailure", code: 1)
            }
        )

        let matches = defaults.dictionary(
            forKey: JellyfinManualMatchPersistence.defaultsKey
        ) as? [String: Int]
        XCTAssertEqual(matches?[key], 111)
        XCTAssertEqual(matches?["https://other.example.com|item-1"], 222)
    }

    func testFailedPersistenceRemovesNewMapping() {
        let defaults = makeDefaults()
        let key = "https://media.example.com|new-item"

        XCTAssertThrowsError(
            try JellyfinManualMatchPersistence.save(
                tmdbID: 456,
                for: key,
                in: defaults
            ) {
                throw NSError(domain: "PersistenceFailure", code: 2)
            }
        )

        let matches = defaults.dictionary(
            forKey: JellyfinManualMatchPersistence.defaultsKey
        ) as? [String: Int]
        XCTAssertNil(matches?[key])
    }

    func testInvalidMatchDoesNotWriteOrRunPersistence() {
        let defaults = makeDefaults()
        var persistenceWasCalled = false

        XCTAssertThrowsError(
            try JellyfinManualMatchPersistence.save(
                tmdbID: 0,
                for: "https://media.example.com|item-1",
                in: defaults
            ) {
                persistenceWasCalled = true
            }
        )

        XCTAssertFalse(persistenceWasCalled)
        XCTAssertNil(defaults.dictionary(forKey: JellyfinManualMatchPersistence.defaultsKey))
    }
}
