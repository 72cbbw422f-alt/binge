import Foundation
import SwiftData

enum BingeWatchEventType: String, Codable {
    case statusChanged
    case episodeWatched
    case episodeUnwatched
}

@Model
final class BingeWatchEvent {
    var eventTypeRaw: String
    var tmdbID: Int
    var mediaKindRaw: String
    var title: String
    var detail: String
    var occurredAt: Date

    init(type: BingeWatchEventType, tmdbID: Int, mediaKind: BingeMediaKind, title: String, detail: String = "") {
        self.eventTypeRaw = type.rawValue
        self.tmdbID = tmdbID
        self.mediaKindRaw = mediaKind.rawValue
        self.title = title
        self.detail = detail
        self.occurredAt = .now
    }

    var eventType: BingeWatchEventType {
        BingeWatchEventType(rawValue: eventTypeRaw) ?? .statusChanged
    }

    var mediaKind: BingeMediaKind {
        BingeMediaKind(rawValue: mediaKindRaw) ?? .movie
    }

    var summary: String {
        switch eventType {
        case .statusChanged: return detail
        case .episodeWatched: return "Markerade \(detail) som sett"
        case .episodeUnwatched: return "Ångrade settmarkering för \(detail)"
        }
    }
}
