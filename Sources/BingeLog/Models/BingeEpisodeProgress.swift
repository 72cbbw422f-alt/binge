import Foundation
import SwiftData

@Model
final class BingeEpisodeProgress {
    var seriesTMDBID: Int
    var seasonNumber: Int
    var episodeNumber: Int
    var episodeName: String
    var watchedAt: Date?

    init(seriesTMDBID: Int, seasonNumber: Int, episodeNumber: Int, episodeName: String) {
        self.seriesTMDBID = seriesTMDBID
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.episodeName = episodeName
    }

    var isWatched: Bool { watchedAt != nil }
}
