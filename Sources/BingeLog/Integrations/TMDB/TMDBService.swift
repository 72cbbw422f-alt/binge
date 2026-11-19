import Foundation

enum TMDBError: LocalizedError {
    case missingToken
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Lägg till din TMDB API Read Access Token i inställningarna."
        case .invalidResponse:
            "TMDB skickade ett svar som inte kunde läsas."
        case .httpStatus(let code):
            "TMDB svarade med felkod \(code). Kontrollera token och försök igen."
        }
    }
}

struct TMDBService {
    private let baseURL = URL(string: "https://api.themoviedb.org/3")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func details(id: Int, mediaKind: BingeMediaKind) async throws -> TMDBDetailResponse {
        let endpoint = mediaKind == .movie ? "movie" : "tv"
        var components = URLComponents(
            url: baseURL.appendingPathComponent("\(endpoint)/\(id)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "language", value: "sv-SE"),
            URLQueryItem(name: "append_to_response", value: "credits,videos")
        ]
        let data = try await data(for: components?.url)
        return try JSONDecoder().decode(TMDBDetailResponse.self, from: data)
    }

    func seasonDetails(seriesID: Int, seasonNumber: Int) async throws -> TMDBSeasonResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("tv/\(seriesID)/season/\(seasonNumber)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "language", value: "sv-SE")]
        let data = try await data(for: components?.url)
        return try JSONDecoder().decode(TMDBSeasonResponse.self, from: data)
    }

    func searchMulti(query: String, page: Int = 1) async throws -> TMDBSearchResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("search/multi"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "language", value: "sv-SE"),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "page", value: String(page))
        ]
        let data = try await data(for: components?.url)
        return try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
    }

    func trending(page: Int = 1) async throws -> TMDBSearchResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("trending/all/week"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "language", value: "sv-SE"),
            URLQueryItem(name: "page", value: String(page))
        ]
        let data = try await data(for: components?.url)
        return try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
    }

    private func data(for url: URL?) async throws -> Data {
        guard let token = SecureTokenStore.read(service: "BingeLog.TMDB") else {
            throw TMDBError.missingToken
        }
        guard let url else { throw TMDBError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw TMDBError.httpStatus(httpResponse.statusCode)
        }
        return data
    }
}
