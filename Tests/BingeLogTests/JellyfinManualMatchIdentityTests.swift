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

    func testMigrationSkipsNonPositiveLegacyTMDBIDs() {
        let migrated = JellyfinManualMatchIdentity.migratedMatches(
            legacy: ["valid": 123, "zero": 0, "negative": -5],
            existing: [:],
            server: "https://media.example.com"
        )

        XCTAssertEqual(migrated?["https://media.example.com|valid"], 123)
        XCTAssertNil(migrated?["https://media.example.com|zero"])
        XCTAssertNil(migrated?["https://media.example.com|negative"])
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

    func testServerIdentityPreservesPortAndNormalizesPathAndQuery() {
        XCTAssertEqual(
            JellyfinManualMatchIdentity.serverIdentity(for: "HTTP://MEDIA.EXAMPLE.COM:8096/library///?api_key=secret"),
            "http://media.example.com:8096/library"
        )
    }

    func testServerIdentityRejectsUnsupportedSchemesAndEmbeddedCredentials() {
        XCTAssertNil(JellyfinManualMatchIdentity.serverIdentity(for: "ftp://media.example.com"))
        XCTAssertNil(JellyfinManualMatchIdentity.serverIdentity(for: "https://user:password@media.example.com"))
    }

    func testServerIdentityTreatsSchemeAndHostCaseAsEquivalent() {
        let first = JellyfinManualMatchIdentity.serverIdentity(for: "HTTPS://Media.Example.com")
        let second = JellyfinManualMatchIdentity.serverIdentity(for: "https://media.example.com/")
        XCTAssertEqual(first, second)
    }

    func testLibraryItemDecodesTMDBIdentityAndWatchedState() throws {
        let json = """
        {
          "Id": "jellyfin-123",
          "Name": "Example Film",
          "Type": "Movie",
          "ProductionYear": 2024,
          "ProviderIds": { "Tmdb": "98765" },
          "UserData": {
            "Played": true,
            "PlayCount": 2,
            "LastPlayedDate": "2026-11-18T20:00:00.0000000Z"
          }
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(JellyfinLibraryItem.self, from: json)

        XCTAssertEqual(item.id, "jellyfin-123")
        XCTAssertEqual(item.name, "Example Film")
        XCTAssertEqual(item.mediaKind, .movie)
        XCTAssertEqual(item.tmdbID, 98765)
        XCTAssertEqual(item.productionYear, 2024)
        XCTAssertEqual(item.userData?.played, true)
        XCTAssertEqual(item.userData?.playCount, 2)
    }

    func testLibraryItemRejectsMissingNonNumericZeroAndNegativeTMDBIDs() throws {
        for rawID in ["not-a-number", "0", "-12", ""] {
            let json = """
            {
              "Id": "jellyfin-invalid-\(rawID)",
              "Name": "Invalid TMDB",
              "Type": "Movie",
              "ProviderIds": { "Tmdb": "\(rawID)" }
            }
            """.data(using: .utf8)!

            let item = try JSONDecoder().decode(JellyfinLibraryItem.self, from: json)
            XCTAssertNil(item.tmdbID, "Expected TMDB ID '\(rawID)' to be rejected")
        }
    }

    func testLibraryItemWithoutTMDBIDRemainsEligibleForManualMatch() throws {
        let json = """
        {
          "Id": "jellyfin-456",
          "Name": "Unmatched Series",
          "Type": "Series"
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(JellyfinLibraryItem.self, from: json)

        XCTAssertEqual(item.mediaKind, .tv)
        XCTAssertNil(item.tmdbID)
        XCTAssertNil(item.userData?.played)
    }

    func testLibraryResponseDecodesItemsAndTotalRecordCount() throws {
        let json = """
        {
          "Items": [
            { "Id": "movie-1", "Name": "First Film", "Type": "Movie" },
            { "Id": "series-1", "Name": "First Series", "Type": "Series" }
          ],
          "TotalRecordCount": 425
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(JellyfinLibraryResponse.self, from: json)

        XCTAssertEqual(response.items.count, 2)
        XCTAssertEqual(response.totalRecordCount, 425)
        XCTAssertEqual(response.items.map(\.id), ["movie-1", "series-1"])
    }

    func testUnsupportedJellyfinItemTypeIsNotTreatedAsMovieOrSeries() throws {
        let json = """
        {
          "Id": "episode-1",
          "Name": "Episode One",
          "Type": "Episode"
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder().decode(JellyfinLibraryItem.self, from: json)

        XCTAssertNil(item.mediaKind)
    }

    func testPaginationAdvancesWhenMorePagesRemain() {
        XCTAssertEqual(
            JellyfinLibraryPagination.nextStartIndex(
                currentStartIndex: 0,
                receivedCount: 200,
                totalRecordCount: 425,
                pageSize: 200
            ),
            200
        )
    }

    func testPaginationStopsAtReportedTotal() {
        XCTAssertNil(
            JellyfinLibraryPagination.nextStartIndex(
                currentStartIndex: 200,
                receivedCount: 25,
                totalRecordCount: 225,
                pageSize: 200
            )
        )
    }

    func testPaginationStopsOnEmptyPageOrShortUnknownTotalPage() {
        XCTAssertNil(
            JellyfinLibraryPagination.nextStartIndex(
                currentStartIndex: 400,
                receivedCount: 0,
                totalRecordCount: 425,
                pageSize: 200
            )
        )
        XCTAssertNil(
            JellyfinLibraryPagination.nextStartIndex(
                currentStartIndex: 0,
                receivedCount: 12,
                totalRecordCount: nil,
                pageSize: 200
            )
        )
    }

    func testPaginationContinuesFullPageWhenTotalIsUnknown() {
        XCTAssertEqual(
            JellyfinLibraryPagination.nextStartIndex(
                currentStartIndex: 200,
                receivedCount: 200,
                totalRecordCount: nil,
                pageSize: 200
            ),
            400
        )
    }
}
