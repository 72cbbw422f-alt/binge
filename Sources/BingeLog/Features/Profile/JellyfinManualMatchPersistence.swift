import Foundation

/// Persists a server-scoped Jellyfin match before the related SwiftData write.
/// If the SwiftData transaction fails, the previous mapping is restored.
enum JellyfinManualMatchPersistence {
    static let defaultsKey = "BingeLog.Jellyfin.ManualMatchesByServer"

    enum Failure: Error {
        case invalidMatch
    }

    static func save(
        tmdbID: Int,
        for key: String,
        in defaults: UserDefaults = .standard,
        persist: () throws -> Void
    ) throws {
        guard tmdbID > 0, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure.invalidMatch
        }

        var matches = defaults.dictionary(forKey: defaultsKey) as? [String: Int] ?? [:]
        let previousValue = matches[key]
        matches[key] = tmdbID
        defaults.set(matches, forKey: defaultsKey)

        do {
            try persist()
        } catch {
            if let previousValue {
                matches[key] = previousValue
            } else {
                matches.removeValue(forKey: key)
            }
            defaults.set(matches, forKey: defaultsKey)
            throw error
        }
    }
}
