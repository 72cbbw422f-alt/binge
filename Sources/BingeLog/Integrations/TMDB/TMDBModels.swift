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

struct TMDBDetailResponse: Decodable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let runtime: Int?
    let episodeRunTime: [Int]?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let genres: [TMDBGenre]?
    let credits: TMDBCredits?
    let videos: TMDBVideos?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, runtime, genres, credits, videos
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case episodeRunTime = "episode_run_time"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
    }

    var displayTitle: String { title ?? name ?? "Okänd titel" }
    var year: String? {
        let date = releaseDate ?? firstAirDate
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
    var backdropURL: URL? {
        guard let backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\\(backdropPath)")
    }
    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\\(posterPath)")
    }
    var durationText: String? {
        if let runtime, runtime > 0 { return "\\(runtime) min" }
        if let first = episodeRunTime?.first { return "\\(first) min/avsnitt" }
        return nil
    }
}

struct TMDBGenre: Decodable, Identifiable {
    let id: Int
    let name: String
}

struct TMDBCredits: Decodable {
    let cast: [TMDBCastMember]?
}

struct TMDBCastMember: Decodable, Identifiable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }
    var profileURL: URL? {
        guard let profilePath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\\(profilePath)")
    }
}

struct TMDBVideos: Decodable {
    let results: [TMDBVideo]
}

struct TMDBVideo: Decodable, Identifiable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    var youtubeURL: URL? {
        guard site == "YouTube" else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\\(key)")
    }
}
