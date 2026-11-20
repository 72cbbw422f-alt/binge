import SwiftData
import XCTest
@testable import BingeLog

@MainActor
final class DetailViewPersistenceTests: XCTestCase {
    func testTransactionPersistsEntryProgressAndWatchEventTogether() throws {
        let container = try makeContainer()

        try DetailViewPersistence.perform(in: container) { context in
            let entry = BingeEntry(
                tmdbID: 100,
                mediaKind: .tv,
                title: "Testserie",
                status: .watching
            )
            entry.userRating = 8.5
            context.insert(entry)

            let progress = BingeEpisodeProgress(
                seriesTMDBID: 100,
                seasonNumber: 1,
                episodeNumber: 2,
                episodeName: "Avsnitt två"
            )
            progress.watchedAt = .now
            context.insert(progress)

            context.insert(BingeWatchEvent(
                type: .episodeWatched,
                tmdbID: 100,
                mediaKind: .tv,
                title: "Testserie",
                detail: "S1 · A2 – Avsnitt två"
            ))
        }

        let verificationContext = ModelContext(container)
        let entries = try verificationContext.fetch(FetchDescriptor<BingeEntry>())
        let progress = try verificationContext.fetch(FetchDescriptor<BingeEpisodeProgress>())
        let events = try verificationContext.fetch(FetchDescriptor<BingeWatchEvent>())

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.status, .watching)
        XCTAssertEqual(entries.first?.userRating, 8.5)
        XCTAssertEqual(progress.count, 1)
        XCTAssertTrue(progress.first?.isWatched == true)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.eventType, .episodeWatched)
    }

    func testFailedTransactionRollsBackOnlyItsOwnChanges() throws {
        let container = try makeContainer()
        let mainContext = ModelContext(container)
        mainContext.autosaveEnabled = false
        let pendingEntry = BingeEntry(
            tmdbID: 200,
            mediaKind: .movie,
            title: "Osparad ändring"
        )
        mainContext.insert(pendingEntry)
        XCTAssertTrue(mainContext.hasChanges)

        XCTAssertThrowsError(try DetailViewPersistence.perform(in: container) { context in
            context.insert(BingeEntry(
                tmdbID: 300,
                mediaKind: .movie,
                title: "Ska återställas"
            ))
            throw TestFailure.expected
        })

        XCTAssertTrue(mainContext.hasChanges)
        XCTAssertEqual(pendingEntry.title, "Osparad ändring")

        let verificationContext = ModelContext(container)
        let persistedEntries = try verificationContext.fetch(FetchDescriptor<BingeEntry>())
        XCTAssertTrue(persistedEntries.isEmpty)
    }

    func testTransactionCanUpdateExistingEntryWithoutReplacingPersonalData() throws {
        let container = try makeContainer()
        let seedContext = ModelContext(container)
        let entry = BingeEntry(
            tmdbID: 400,
            mediaKind: .movie,
            title: "Min film",
            status: .planned
        )
        entry.userRating = 9
        seedContext.insert(entry)
        try seedContext.save()

        try DetailViewPersistence.perform(in: container) { context in
            let descriptor = FetchDescriptor<BingeEntry>(
                predicate: #Predicate { $0.tmdbID == 400 && $0.mediaKindRaw == "movie" }
            )
            let fetched = try context.fetch(descriptor)
            let target = try XCTUnwrap(fetched.first)
            target.status = .completed
            target.completedAt = .now
            context.insert(BingeWatchEvent(
                type: .statusChanged,
                tmdbID: target.tmdbID,
                mediaKind: target.mediaKind,
                title: target.title,
                detail: "Vill se → Sett klart"
            ))
        }

        let verificationContext = ModelContext(container)
        let entries = try verificationContext.fetch(FetchDescriptor<BingeEntry>())
        let events = try verificationContext.fetch(FetchDescriptor<BingeWatchEvent>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.status, .completed)
        XCTAssertEqual(entries.first?.userRating, 9)
        XCTAssertNotNil(entries.first?.completedAt)
        XCTAssertEqual(events.count, 1)
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

    private enum TestFailure: Error {
        case expected
    }
}
