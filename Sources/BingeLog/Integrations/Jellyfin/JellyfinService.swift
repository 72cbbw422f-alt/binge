import Foundation

enum JellyfinError: LocalizedError {
    case invalidServerAddress
    case invalidResponse
    case httpStatus(Int)
    case missingConnection

    var errorDescription: String? {
        switch self {
        case .invalidServerAddress:
            "Ange en giltig serveradress som börjar med http:// eller https://."
        case .invalidResponse:
            "Jellyfin skickade ett svar som inte kunde läsas."
        case .httpStatus(let code):
            switch code {
            case 401: "Inloggningen misslyckades. Kontrollera användarnamn och lösenord."
            case 403: "Jellyfin nekade åtkomst till kontot."
            case 404: "Jellyfin-servern hittades inte på den adressen."
            default: "Jellyfin svarade med felkod \(code)."
            }
        case .missingConnection:
            "Jellyfin är inte anslutet."
        }
    }
}

struct JellyfinAuthResult: Decodable {
    let accessToken: String
    let user: JellyfinUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "AccessToken"
        case user = "User"
    }
}

struct JellyfinUser: Decodable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}


struct JellyfinLibraryResponse: Decodable {
    let items: [JellyfinLibraryItem]
    let totalRecordCount: Int?
    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}

/// Deterministic pagination rules shared by the service and unit tests.
enum JellyfinLibraryPagination {
    static func nextStartIndex(
        currentStartIndex: Int,
        receivedCount: Int,
        totalRecordCount: Int?,
        pageSize: Int
    ) -> Int? {
        guard receivedCount > 0 else { return nil }
        let nextIndex = currentStartIndex + receivedCount
        if let totalRecordCount, nextIndex >= totalRecordCount { return nil }
        if totalRecordCount == nil, receivedCount < pageSize { return nil }
        return nextIndex
    }
}

struct JellyfinUserData: Decodable {
    let played: Bool?
    let playCount: Int?
    let lastPlayedDate: String?

    enum CodingKeys: String, CodingKey {
        case played = "Played"
        case playCount = "PlayCount"
        case lastPlayedDate = "LastPlayedDate"
    }
}

struct JellyfinLibraryItem: Decodable, Identifiable {
    let id: String
    let name: String
    let type: String
    let productionYear: Int?
    let overview: String?
    let providerIds: [String: String]?
    let userData: JellyfinUserData?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case productionYear = "ProductionYear"
        case overview = "Overview"
        case providerIds = "ProviderIds"
        case userData = "UserData"
    }

    var tmdbID: Int? {
        guard let raw = providerIds?["Tmdb"] else { return nil }
        return Int(raw)
    }

    var mediaKind: BingeMediaKind? {
        switch type {
        case "Movie": return .movie
        case "Series": return .tv
        default: return nil
        }
    }
}

struct JellyfinService {
    private let session: URLSession
    private static let clientName = "BingeLog"
    private static let clientVersion = "1.0.0"
    private static let deviceName = "iPhone"

    init(session: URLSession = .shared) {
        self.session = session
    }

    static var deviceID: String {
        if let saved = UserDefaults.standard.string(forKey: "BingeLog.Jellyfin.DeviceID") {
            return saved
        }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: "BingeLog.Jellyfin.DeviceID")
        return value
    }

    func authenticate(serverAddress: String, username: String, password: String) async throws -> JellyfinAuthResult {
        guard let baseURL = normalizedServerURL(serverAddress) else {
            throw JellyfinError.invalidServerAddress
        }
        let url = baseURL.appendingPathComponent("Users").appendingPathComponent("AuthenticateByName")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authorizationHeader(), forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "Username": username,
            "Pw": password
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw JellyfinError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw JellyfinError.httpStatus(http.statusCode) }
        let result: JellyfinAuthResult
        do {
            result = try JSONDecoder().decode(JellyfinAuthResult.self, from: data)
        } catch {
            throw JellyfinError.invalidResponse
        }

        guard !result.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !result.user.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !result.user.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JellyfinError.invalidResponse
        }
        return result
    }


    func libraryItems() async throws -> [JellyfinLibraryItem] {
        guard let server = SecureTokenStore.read(service: "BingeLog.Jellyfin.Server"),
              let token = SecureTokenStore.read(service: "BingeLog.Jellyfin.Token"),
              let userID = SecureTokenStore.read(service: "BingeLog.Jellyfin.UserID") else {
            throw JellyfinError.missingConnection
        }
        return try await libraryItems(server: server, userID: userID, token: token)
    }

    /// Internal overload keeps the HTTP pagination flow testable without Keychain state.
    func libraryItems(server: String, userID: String, token: String) async throws -> [JellyfinLibraryItem] {
        guard let baseURL = normalizedServerURL(server) else {
            throw JellyfinError.invalidServerAddress
        }

        let pageSize = 200
        var startIndex = 0
        var allItems: [JellyfinLibraryItem] = []
        while true {
            var components = URLComponents(
                url: baseURL.appendingPathComponent("Users").appendingPathComponent(userID).appendingPathComponent("Items"),
                resolvingAgainstBaseURL: false
            )
            components?.queryItems = [
                URLQueryItem(name: "Recursive", value: "true"),
                URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series"),
                URLQueryItem(name: "Fields", value: "ProviderIds,Overview,ProductionYear"),
                URLQueryItem(name: "EnableUserData", value: "true"),
                URLQueryItem(name: "SortBy", value: "SortName"),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
                URLQueryItem(name: "StartIndex", value: String(startIndex)),
                URLQueryItem(name: "Limit", value: String(pageSize))
            ]
            guard let url = components?.url else { throw JellyfinError.invalidResponse }

            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            request.setValue(authorizationHeader(token: token), forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw JellyfinError.invalidResponse }
            guard (200...299).contains(http.statusCode) else { throw JellyfinError.httpStatus(http.statusCode) }
            let page: JellyfinLibraryResponse
            do {
                page = try JSONDecoder().decode(JellyfinLibraryResponse.self, from: data)
            } catch {
                throw JellyfinError.invalidResponse
            }

            allItems.append(contentsOf: page.items)
            guard let nextIndex = JellyfinLibraryPagination.nextStartIndex(
                currentStartIndex: startIndex,
                receivedCount: page.items.count,
                totalRecordCount: page.totalRecordCount,
                pageSize: pageSize
            ) else {
                break
            }
            startIndex = nextIndex
        }

        return allItems
    }

    func disconnect() async {
        guard let server = SecureTokenStore.read(service: "BingeLog.Jellyfin.Server"),
              let token = SecureTokenStore.read(service: "BingeLog.Jellyfin.Token"),
              let baseURL = normalizedServerURL(server) else {
            clearCredentials()
            return
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("Sessions").appendingPathComponent("Logout"))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue(authorizationHeader(token: token), forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
        clearCredentials()
    }

    static func saveConnection(server: String, username: String, userID: String, token: String) -> Bool {
        let credentials: [(String, String)] = [
            (server, "BingeLog.Jellyfin.Server"),
            (username, "BingeLog.Jellyfin.Username"),
            (userID, "BingeLog.Jellyfin.UserID"),
            (token, "BingeLog.Jellyfin.Token")
        ]

        for (value, service) in credentials {
            guard SecureTokenStore.save(value, service: service) else {
                for (_, storedService) in credentials {
                    SecureTokenStore.delete(service: storedService)
                }
                return false
            }
        }
        return true
    }

    private func clearCredentials() {
        SecureTokenStore.delete(service: "BingeLog.Jellyfin.Server")
        SecureTokenStore.delete(service: "BingeLog.Jellyfin.Username")
        SecureTokenStore.delete(service: "BingeLog.Jellyfin.UserID")
        SecureTokenStore.delete(service: "BingeLog.Jellyfin.Token")
    }

    private func normalizedServerURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host != nil,
              components.user == nil,
              components.password == nil else { return nil }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = path.isEmpty ? "" : "/" + path
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { return nil }
        return url
    }

    private func authorizationHeader(token: String? = nil) -> String {
        let deviceID = Self.deviceID
        var value = "MediaBrowser Client=\"\(Self.clientName)\", Device=\"\(Self.deviceName)\", DeviceId=\"\(deviceID)\", Version=\"\(Self.clientVersion)\""
        if let token { value += ", Token=\"\(token)\"" }
        return value
    }
}
