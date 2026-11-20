import SwiftData
import XCTest
@testable import BingeLog

@MainActor
final class JellyfinWatchStatePersistenceTests: XCTestCase {
    func testConfirmedWatchedStatePreservesPersonalDataAndRecordsOneEvent() throws {
        let container = try makeContainer()
        let seed = ModelContext(container)
        let entry = BingeEntry(
            tmdbID: 700,
            mediaKind: .movie,
            title: "Personlig favorit",
            status: .watching
        )
        entry.userRating = 9.5
        seed.insert(entry)
        try seed.save()
        let originalAddedAt = entry.addedAt

        XCTAssertTrue(try JellyfinWatchStatePersistence.markCompleted(
            tmdbID: 700,
            mediaKind: .movie,
            in: container
        ))

        let verification = ModelContext(container)
        let entries = try verification.fetch(FetchDescriptor<BingeEntry>())
        let events = try verification.fetch(FetchDescriptor<BingeWatchEvent>())

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.status, .completed)
        XCTAssertEqual(entries.first?.userRating, 9.5)
        XCTAssertEqual(entries.first?.startedAt, originalAddedAt)
        XCTAssertNotNil(entries.first?.completedAt)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.eventType, .statusChanged)
        XCTAssertEqual(events.first?.detail, "Markerad som Sett klart via Jellyfin")
    }

    func testRepeatedWatchedStateDoesNotRewriteDatesOrDuplicateEvents() throws {
        let container = try makeContainer()
        let seed = ModelContext(container)
        let entry = BingeEntry(
            tmdbID: 701,
            mediaKind: .tv,
            title: "Redan påbörjad",
            status: .watching
        )
        let originalStart = Date(timeIntervalSince1970: 1_700_000_000)
        entry.startedAt = originalStart
        seed.insert(entry)
        try seed.save()

        XCTAssertTrue(try JellyfinWatchStatePersistence.markCompleted(
            tmdbID: 701,
            mediaKind: .tv,
            in: container
        ))
        let firstVerification = ModelContext(container)
        let firstEntry = try XCTUnwrap(firstVerification.fetch(FetchDescriptor<BingeEntry>()).first)
        let completedAt = try XCTUnwrap(firstEntry.completedAt)

        XCTAssertFalse(try JellyfinWatchStatePersistence.markCompleted(
            tmdbID: 701,
            mediaKind: .tv,
            in: container
        ))

        let verification = ModelContext(container)
        let finalEntry = try XCTUnwrap(verification.fetch(FetchDescriptor<BingeEntry>()).first)
        let events = try verification.fetch(FetchDescriptor<BingeWatchEvent>())
        XCTAssertEqual(finalEntry.startedAt, originalStart)
        XCTAssertEqual(finalEntry.completedAt, completedAt)
        XCTAssertEqual(events.count, 1)
    }

    func testMissingLocalTitleFailsWithoutCreatingAnEvent() throws {
        let container = try makeContainer()

        XCTAssertThrowsError(try JellyfinWatchStatePersistence.markCompleted(
            tmdbID: 702,
            mediaKind: .movie,
            in: container
        ))

        let verification = ModelContext(container)
        XCTAssertTrue(try verification.fetch(FetchDescriptor<BingeWatchEvent>()).isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: BingeEntry.self,
            BingeEpisodeProgress.self,
            BingeWatchEvent.self,
            configurations: configuration
        )
    }
}
