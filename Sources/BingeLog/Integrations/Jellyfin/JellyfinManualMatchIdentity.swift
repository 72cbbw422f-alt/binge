import Foundation

/// Pure identity and migration rules for Jellyfin manual TMDB matches.
/// Kept outside SwiftUI so the rules can be covered by unit tests.
enum JellyfinManualMatchIdentity {
    static func serverIdentity(for rawServer: String) -> String? {
        guard var components = URLComponents(
            string: rawServer.trimmingCharacters(in: .whitespacesAndNewlines)
        ),
        let scheme = components.scheme,
        let host = components.host else {
            return nil
        }

        components.scheme = scheme.lowercased()
        components.host = host.lowercased()
        components.path = components.path.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        components.query = nil
        components.fragment = nil
        return components.string
    }

    static func key(server: String, itemID: String) -> String {
        let identity = serverIdentity(for: server) ?? server
        return "\(identity)|\(itemID)"
    }

    /// Returns nil when there is nothing safe to migrate.
    /// Existing server-scoped values always win over legacy values.
    static func migratedMatches(
        legacy: [String: Int],
        existing: [String: Int],
        server: String
    ) -> [String: Int]? {
        guard !legacy.isEmpty, let identity = serverIdentity(for: server) else {
            return nil
        }

        var result = existing
        for (itemID, tmdbID) in legacy {
            let scopedKey = "\(identity)|\(itemID)"
            if result[scopedKey] == nil {
                result[scopedKey] = tmdbID
            }
        }
        return result
    }
}
