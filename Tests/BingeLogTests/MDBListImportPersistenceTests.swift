import SwiftData
import XCTest
@testable import BingeLog

@MainActor
final class MDBListImportPersistenceTests: XCTestCase {
    func testImportAddsMoviesAndShowsAndSkipsDuplicateKeys() throws {
        let container = try makeContainer()
        let movie = try decodeItem("""
        { "id": 1, "tmdbid": 100, "mediatype": "movie", "title": "Film" }
        """)
        let duplicateMovie = try decodeItem("""
        { "id": 2, "tmdbid": 100, "mediatype": "movie", "title": "Duplicate film" }
        """)
        let show = try decodeItem("""
        { "id": 3, "tmdbid": 100, "mediatype": "show", "title": "Series" }
        """)

        let summary = try MDBListImportPersistence.importItems(
            [movie, duplicateMovie, show],
            into: container
        )

        XCTAssertEqual(summary.added, 2)
        XCTAssertEqual(summary.skipped, 1)

        let verificationContext = ModelContext(container)
        let entries = try verificationContext.fetch(FetchDescriptor<BingeEntry>())
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.mediaKind == .movie && $0.tmdbID == 100 })
        XCTAssertTrue(entries.contains { $0.mediaKind == .tv && $0.tmdbID == 100 })
    }

    func testExistingEntryStatusAndPersonalRatingArePreserved() throws {
        let container = try makeContainer()
        let seedContext = ModelContext(container)
        let existing = BingeEntry(
            tmdbID: 200,
            mediaKind: .movie,
            title: "Existing film",
            status: .completed
        )
        existing.userRating = 9.5
        seedContext.insert(existing)
        try seedContext.save()

        let imported = try decodeItem("""
        { "id": 1, "tmdbid": 200, "mediatype": "movie", "title": "Updated external title" }
        """)
        let summary = try MDBListImportPersistence.importItems([imported], into: container)

        XCTAssertEqual(summary.added, 0)
        XCTAssertEqual(summary.skipped, 1)

        let verificationContext = ModelContext(container)
        let entries = try verificationContext.fetch(FetchDescriptor<BingeEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "Existing film")
        XCTAssertEqual(entries[0].status, .completed)
        XCTAssertEqual(entries[0].userRating, 9.5)
    }

    func testImportDoesNotRollbackUnrelatedPendingChangesInMainContext() throws {
        let container = try makeContainer()
        let mainContext = ModelContext(container)
        let pendingEntry = BingeEntry(
            tmdbID: 300,
            mediaKind: .movie,
            title: "Unsaved local edit"
        )
        mainContext.insert(pendingEntry)

        XCTAssertTrue(mainContext.hasChanges)

        let imported = try decodeItem("""
        { "id": 1, "tmdbid": 400, "mediatype": "movie", "title": "Imported film" }
        """)
        let summary = try MDBListImportPersistence.importItems([imported], into: container)

        XCTAssertEqual(summary.added, 1)
        XCTAssertTrue(mainContext.hasChanges)
        XCTAssertEqual(pendingEntry.title, "Unsaved local edit")
    }

    func testItemsWithoutUsableIdentityAreSkipped() throws {
        let container = try makeContainer()
        let missingID = try decodeItem("""
        { "id": 1, "mediatype": "movie", "title": "Missing TMDB ID" }
        """)
        let unsupportedType = try decodeItem("""
        { "id": 2, "tmdbid": 500, "mediatype": "person", "title": "Unsupported type" }
        """)

        let summary = try MDBListImportPersistence.importItems(
            [missingID, unsupportedType],
            into: container
        )

        XCTAssertEqual(summary.added, 0)
        XCTAssertEqual(summary.skipped, 2)
        let verificationContext = ModelContext(container)
        XCTAssertTrue(try verificationContext.fetch(FetchDescriptor<BingeEntry>()).isEmpty)
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

    private func decodeItem(_ json: String) throws -> MDBListItem {
        try JSONDecoder().decode(MDBListItem.self, from: Data(json.utf8))
    }
}
