import Foundation
import SwiftData

struct MDBListImportSummary {
    let added: Int
    let skipped: Int
}

enum MDBListImportPersistence {
    /// Imports a complete MDBList response in an isolated context.
    /// A failed save can therefore roll back this import without discarding
    /// unrelated pending edits in the app's main ModelContext.
    @MainActor
    static func importItems(_ items: [MDBListItem], into container: ModelContainer) throws -> MDBListImportSummary {
        let importContext = ModelContext(container)
        importContext.autosaveEnabled = false

        do {
            let existingEntries = try importContext.fetch(FetchDescriptor<BingeEntry>())
            var knownKeys = Set(existingEntries.map { key(mediaKind: $0.mediaKind, tmdbID: $0.tmdbID) })
            var added = 0
            var skipped = 0

            for item in items {
                guard let tmdbID = item.tmdbID,
                      tmdbID > 0,
                      let title = item.title,
                      !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let rawType = item.importMediaType else {
                    skipped += 1
                    continue
                }

                let mediaKind: BingeMediaKind = rawType == "movie" ? .movie : .tv
                guard knownKeys.insert(key(mediaKind: mediaKind, tmdbID: tmdbID)).inserted else {
                    skipped += 1
                    continue
                }

                let releaseDate = item.year.map { String($0) + "-01-01" }
                let entry = BingeEntry(
                    tmdbID: tmdbID,
                    mediaKind: mediaKind,
                    title: title,
                    posterPath: normalizedPosterPath(item.poster),
                    overview: item.overview ?? "",
                    releaseDate: releaseDate,
                    status: .planned
                )
                importContext.insert(entry)
                added += 1
            }

            try importContext.save()
            return MDBListImportSummary(added: added, skipped: skipped)
        } catch {
            importContext.rollback()
            throw error
        }
    }

    private static func key(mediaKind: BingeMediaKind, tmdbID: Int) -> String {
        "\(mediaKind.rawValue)-\(tmdbID)"
    }

    private static func normalizedPosterPath(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if value.hasPrefix("http"), let url = URL(string: value) {
            return url.path
        }
        return value.hasPrefix("/") ? value : "/" + value
    }
}
