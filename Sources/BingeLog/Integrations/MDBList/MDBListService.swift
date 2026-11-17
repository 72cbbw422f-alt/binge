import Foundation

struct MDBListUserList: Decodable, Identifiable {
    let id: Int
    let name: String
    let itemCount: Int?
    let mediaType: String?

    enum CodingKeys: String, CodingKey {
        case id, name, items, mediatype
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        itemCount = try? c.decode(Int.self, forKey: .items)
        mediaType = try? c.decode(String.self, forKey: .mediatype)
    }
}

struct MDBListItem: Decodable, Identifiable {
    let id: Int
    let tmdbID: Int?
    let mediaType: String?
    let title: String?
    let year: Int?
    let poster: String?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id, tmdbid, mediatype, title, name, year, poster, overview, description
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        if let value = try? c.decode(Int.self, forKey: .tmdbid) {
            tmdbID = value
        } else if let value = try? c.decode(String.self, forKey: .tmdbid) {
            tmdbID = Int(value)
        } else {
            tmdbID = nil
        }
        mediaType = try? c.decode(String.self, forKey: .mediatype)
        title = (try? c.decode(String.self, forKey: .title)) ?? (try? c.decode(String.self, forKey: .name))
        if let value = try? c.decode(Int.self, forKey: .year) {
            year = value
        } else if let value = try? c.decode(String.self, forKey: .year) {
            year = Int(value)
        } else {
            year = nil
        }
        poster = try? c.decode(String.self, forKey: .poster)
        overview = (try? c.decode(String.self, forKey: .overview)) ?? (try? c.decode(String.self, forKey: .description))
    }
}

enum MDBListError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case requestFailed(Int)
    case missingTMDBID

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Ogiltig MDBList-adress."
        case .invalidResponse: "MDBList skickade ett svar som inte kunde läsas."
        case .unauthorized: "API-nyckeln verkar vara fel. Kontrollera den i MDBList-inställningarna."
        case .requestFailed(let code): "MDBList svarade med HTTP \(code)."
        case .missingTMDBID: "Posten saknar TMDB-ID och kan inte matchas säkert."
        }
    }
}

struct MDBListService {
    private let baseURL = URL(string: "https://api.mdblist.com")!

    func userLists(apiKey: String) async throws -> [MDBListUserList] {
        let data = try await request(path: "/lists/user/", apiKey: apiKey)
        return try JSONDecoder().decode([MDBListUserList].self, from: data)
    }

    func listItems(listID: Int, apiKey: String) async throws -> [MDBListItem] {
        var all: [MDBListItem] = []
        var offset = 0
        let pageSize = 100
        while offset < 1000 {
            let data = try await request(
                path: "/lists/\(listID)/items/",
                apiKey: apiKey,
                extra: [URLQueryItem(name: "limit", value: String(pageSize)),
                        URLQueryItem(name: "offset", value: String(offset)),
                        URLQueryItem(name: "append_to_response", value: "poster,description")]
            )
            let page = try JSONDecoder().decode([MDBListItem].self, from: data)
            all.append(contentsOf: page)
            if page.count < pageSize { break }
            offset += page.count
        }
        return all
    }

    private func request(path: String, apiKey: String, extra: [URLQueryItem] = []) async throws -> Data {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw MDBListError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "apikey", value: apiKey)] + extra
        guard let url = components.url else { throw MDBListError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MDBListError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw MDBListError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw MDBListError.requestFailed(http.statusCode) }
        return data
    }
}
