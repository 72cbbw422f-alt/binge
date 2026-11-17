import Foundation
import SwiftData

enum BingeMediaKind: String, Codable, CaseIterable {
    case movie
    case tv

    var title: String { self == .movie ? "Film" : "Serie" }
}

enum BingeWatchStatus: String, Codable, CaseIterable, Identifiable {
    case planned
    case watching
    case completed
    case onHold
    case dropped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planned: "Vill se"
        case .watching: "Tittar på"
        case .completed: "Sett klart"
        case .onHold: "Pausad"
        case .dropped: "Avbruten"
        }
    }

    var symbol: String {
        switch self {
        case .planned: "bookmark"
        case .watching: "play.circle"
        case .completed: "checkmark.circle"
        case .onHold: "pause.circle"
        case .dropped: "xmark.circle"
        }
    }
}

@Model
final class BingeEntry {
    var tmdbID: Int
    var mediaKindRaw: String
    var title: String
    var originalTitle: String
    var posterPath: String?
    var backdropPath: String?
    var overview: String
    var releaseDate: String?
    var tmdbRating: Double?
    var userRating: Double?
    var statusRaw: String
    var addedAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var updatedAt: Date

    init(
        tmdbID: Int,
        mediaKind: BingeMediaKind,
        title: String,
        originalTitle: String = "",
        posterPath: String? = nil,
        backdropPath: String? = nil,
        overview: String = "",
        releaseDate: String? = nil,
        tmdbRating: Double? = nil,
        status: BingeWatchStatus = .planned
    ) {
        self.tmdbID = tmdbID
        self.mediaKindRaw = mediaKind.rawValue
        self.title = title
        self.originalTitle = originalTitle
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.overview = overview
        self.releaseDate = releaseDate
        self.tmdbRating = tmdbRating
        self.statusRaw = status.rawValue
        self.addedAt = .now
        self.updatedAt = .now
    }

    var mediaKind: BingeMediaKind {
        get { BingeMediaKind(rawValue: mediaKindRaw) ?? .movie }
        set { mediaKindRaw = newValue.rawValue }
    }

    var status: BingeWatchStatus {
        get { BingeWatchStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue; updatedAt = .now }
    }

    var year: String? {
        guard let releaseDate, releaseDate.count >= 4 else { return nil }
        return String(releaseDate.prefix(4))
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(posterPath)")
    }
}
