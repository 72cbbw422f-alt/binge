import XCTest
@testable import BingeLog

final class JellyfinManualMatchIdentityTests: XCTestCase {
    func testServerIdentityNormalizesSchemeHostAndTrailingSlash() {
        XCTAssertEqual(
            JellyfinManualMatchIdentity.serverIdentity(for: " HTTPS://Media.Example.com/library/?token=abc#top "),
            "https://media.example.com/library"
        )
    }

    func testManualMatchKeyIsScopedToServer() {
        let first = JellyfinManualMatchIdentity.key(
            server: "https://media.example.com",
            itemID: "jellyfin-item-1"
        )
        let second = JellyfinManualMatchIdentity.key(
            server: "https://other.example.com",
            itemID: "jellyfin-item-1"
        )

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first, "https://media.example.com|jellyfin-item-1")
    }

    func testMigrationPreservesExistingScopedMatch() {
        let migrated = JellyfinManualMatchIdentity.migratedMatches(
            legacy: ["item-1": 100, "item-2": 200],
            existing: ["https://media.example.com|item-1": 999],
            server: "https://media.example.com"
        )

        XCTAssertEqual(migrated?["https://media.example.com|item-1"], 999)
        XCTAssertEqual(migrated?["https://media.example.com|item-2"], 200)
    }

    func testMigrationDoesNotCrossServerBoundaries() {
        let migrated = JellyfinManualMatchIdentity.migratedMatches(
            legacy: ["same-item-id": 321],
            existing: ["https://other.example.com|same-item-id": 654],
            server: "https://media.example.com"
        )

        XCTAssertEqual(migrated?["https://media.example.com|same-item-id"], 321)
        XCTAssertEqual(migrated?["https://other.example.com|same-item-id"], 654)
    }

    func testMigrationRejectsEmptyLegacyDataOrInvalidServer() {
        XCTAssertNil(
            JellyfinManualMatchIdentity.migratedMatches(
                legacy: [:],
                existing: [:],
                server: "https://media.example.com"
            )
        )
        XCTAssertNil(
            JellyfinManualMatchIdentity.migratedMatches(
                legacy: ["item-1": 100],
                existing: [:],
                server: "not a server"
            )
        )
    }
}
