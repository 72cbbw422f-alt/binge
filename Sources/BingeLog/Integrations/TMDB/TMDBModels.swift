import Foundation

enum TMDBMediaType: String, Decodable, Hashable {
    case movie
    case tv
    case person
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = TMDBMediaType(rawValue: (try? container.decode(String.self)) ?? "") ?? .unknown
    }

    var displayName: String {
        switch self {
        case .movie: "FILM"
        case .tv: "SERIE"
        case .person: "PERSON"
        case .unknown: "OKÄND"
        }
    }
}

struct TMDBSearchResponse: Decodable {
    let results: [TMDBMediaItem]
    let totalResults: Int

    enum CodingKeys: String, CodingKey {
        case results
        case totalResults = "total_results"
    }
}

struct TMDBMediaItem: Decodable, Identifiable, Hashable {
    let id: Int
    let mediaType: TMDBMediaType?
    let title: String?
    let name: String?
    let originalTitle: String?
    let originalName: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case mediaType = "media_type"
        case originalTitle = "original_title"
        case originalName = "original_name"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
    }

    var displayTitle: String {
        title ?? name ?? originalTitle ?? originalName ?? "Okänd titel"
    }

    var year: String? {
        let date = releaseDate ?? firstAirDate
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    var posterURL: URL? {
        guard let posterPath, !posterPath.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }

    var backdropURL: URL? {
        guard let backdropPath, !backdropPath.isEmpty else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\(backdropPath)")
    }

    var rating: String? {
        guard let voteAverage, voteAverage > 0 else { return nil }
        return String(format: "%.1f", voteAverage)
    }

    static func == (lhs: TMDBMediaItem, rhs: TMDBMediaItem) -> Bool {
        lhs.id == rhs.id && lhs.mediaType == rhs.mediaType
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(mediaType)
    }
}
