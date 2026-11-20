import SwiftData

/// Applies an explicitly confirmed Jellyfin watched state to one local title.
/// Personal ratings and episode-level progress are deliberately untouched.
enum JellyfinWatchStatePersistence {
    @MainActor
    @discardableResult
    static func markCompleted(
        tmdbID: Int,
        mediaKind: BingeMediaKind,
        in container: ModelContainer
    ) throws -> Bool {
        let mediaKindRaw = mediaKind.rawValue
        var didUpdate = false

        try DetailViewPersistence.perform(in: container) { context in
            let descriptor = FetchDescriptor<BingeEntry>(
                predicate: #Predicate {
                    $0.tmdbID == tmdbID && $0.mediaKindRaw == mediaKindRaw
                }
            )
            guard let target = try context.fetch(descriptor).first else {
                throw DetailViewPersistence.Failure.entryNotFound
            }
            guard target.status != .completed else { return }

            target.status = .completed
            if target.startedAt == nil {
                target.startedAt = target.addedAt
            }
            target.completedAt = .now
            context.insert(BingeWatchEvent(
                type: .statusChanged,
                tmdbID: target.tmdbID,
                mediaKind: target.mediaKind,
                title: target.title,
                detail: "Markerad som Sett klart via Jellyfin"
            ))
            didUpdate = true
        }

        return didUpdate
    }
}
