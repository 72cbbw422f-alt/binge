import SwiftData
import SwiftUI

private struct BingeReleaseItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case movie
        case episode
    }

    let id: String
    let title: String
    let detail: String
    let date: Date
    let kind: Kind
    let posterPath: String?

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w342\(posterPath)")
    }

    var symbol: String { kind == .movie ? "film" : "tv" }
    var typeLabel: String { kind == .movie ? "FILMPREMIÄR" : "NYTT AVSNITT" }
}

struct CalendarView: View {
    @Query(sort: \BingeEntry.title) private var entries: [BingeEntry]
    @State private var releases: [BingeReleaseItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var horizon = 30

    private var upcoming: [BingeReleaseItem] {
        let limit = Calendar.current.date(byAdding: .day, value: horizon, to: .now) ?? .now
        return releases.filter { $0.date >= Calendar.current.startOfDay(for: .now) && $0.date <= limit }
            .sorted { $0.date < $1.date }
    }

    private var groupedReleases: [(date: Date, items: [BingeReleaseItem])] {
        let groups = Dictionary(grouping: upcoming) { Calendar.current.startOfDay(for: $0.date) }
        return groups.keys.sorted().map { ($0, groups[$0, default: []]) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                HStack(spacing: 10) {
                    summaryMetric(value: "\(upcoming.count)", label: "Kommande släpp", symbol: "calendar")
                    summaryMetric(value: "\(Set(upcoming.map(\.title)).count)", label: "Titlar", symbol: "sparkles")
                }

                Picker("Period", selection: $horizon) {
                    Text("30 dagar").tag(30)
                    Text("90 dagar").tag(90)
                }
                .pickerStyle(.segmented)
                .tint(BingeTheme.accent)

                if isLoading && releases.isEmpty {
                    loadingState
                } else if let errorMessage {
                    messageCard(title: "Kalendern kunde inte hämtas", message: errorMessage, symbol: "wifi.exclamationmark")
                } else if upcoming.isEmpty {
                    messageCard(
                        title: "Inga kommande släpp ännu",
                        message: entries.isEmpty
                            ? "Lägg till filmer och serier i din samling så håller BingeLog koll på kommande premiärer och avsnitt."
                            : "Vi hittar inga bekräftade premiärer eller avsnitt under den valda perioden för dina sparade titlar.",
                        symbol: "calendar.badge.checkmark"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("PÅ GÅNG")
                                .font(.caption.weight(.bold))
                                .tracking(1.5)
                                .foregroundStyle(BingeTheme.accent)
                            Spacer()
                            if isLoading {
                                ProgressView().tint(BingeTheme.accent).scaleEffect(0.8)
                            } else {
                                Text("\(upcoming.count) händelser")
                                    .font(.caption)
                                    .foregroundStyle(BingeTheme.secondaryText)
                            }
                        }

                        ForEach(groupedReleases, id: \.date) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                dateHeading(group.date)
                                ForEach(group.items) { item in
                                    releaseCard(item)
                                }
                            }
                        }
                    }
                }

                Text("Datumen hämtas från TMDB och kan ändras av distributören. Endast kommande datum visas.")
                    .font(.caption2)
                    .foregroundStyle(BingeTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(BingeTheme.screenPadding)
        }
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadReleases() }
        .refreshable { await loadReleases() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BINGELOG")
                    .font(.caption.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(BingeTheme.accent)
                Spacer()
                Button {
                    Task { await loadReleases() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BingeTheme.accent)
                        .frame(width: 38, height: 38)
                        .background(BingeTheme.surface, in: Circle())
                }
                .disabled(isLoading)
                .accessibilityLabel("Uppdatera kalendern")
            }
            Text("Premiärkalender")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .tracking(-0.8)
                .foregroundStyle(BingeTheme.primaryText)
            Text("Nya avsnitt och filmer från din egen samling.")
                .font(.subheadline)
                .foregroundStyle(BingeTheme.secondaryText)
        }
    }

    private func summaryMetric(value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(BingeTheme.accent)
            Text(value)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(BingeTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(BingeTheme.separator, lineWidth: 1))
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(BingeTheme.accent).scaleEffect(1.1)
            Text("Hämtar kommande premiärer…")
                .font(.subheadline)
                .foregroundStyle(BingeTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
    }

    private func messageCard(title: String, message: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(BingeTheme.accent)
            Text(title).font(.headline).foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(BingeTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if !entries.isEmpty {
                Button("Försök igen") { Task { await loadReleases() } }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BingeTheme.accent)
                    .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(BingeTheme.separator, lineWidth: 1))
    }

    private func dateHeading(_ date: Date) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(BingeTheme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(date.formatted(.dateTime.month(.wide).year()))
                    .font(.caption)
                    .foregroundStyle(BingeTheme.secondaryText)
            }
            Spacer()
        }
        .textCase(.lowercase)
        .padding(.top, 5)
    }

    private func releaseCard(_ item: BingeReleaseItem) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.posterURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        BingeTheme.elevated
                        Image(systemName: item.symbol)
                            .foregroundStyle(BingeTheme.secondaryText)
                    }
                }
            }
            .frame(width: 54, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.typeLabel)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(BingeTheme.accent)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(BingeTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Text("Hela dagen")
                .font(.caption2)
                .foregroundStyle(BingeTheme.secondaryText)
        }
        .padding(11)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BingeTheme.separator, lineWidth: 1))
    }

    @MainActor
    private func loadReleases() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 90, to: start) ?? start
        var found: [BingeReleaseItem] = []
        var fetchError: String?

        for entry in entries {
            if entry.mediaKind == .movie {
                if let date = Self.parseDate(entry.releaseDate), date >= start, date <= end {
                    found.append(BingeReleaseItem(
                        id: "movie-\(entry.tmdbID)",
                        title: entry.title,
                        detail: "Filmpremiär",
                        date: date,
                        kind: .movie,
                        posterPath: entry.posterPath
                    ))
                }
                continue
            }

            do {
                let service = TMDBService()
                let details = try await service.details(id: entry.tmdbID, mediaKind: .tv)
                let seasons = (details.seasons ?? [])
                    .filter { $0.seasonNumber > 0 }
                    .filter { season in
                        guard let date = Self.parseDate(season.airDate) else { return false }
                        return date <= end
                    }
                    .sorted { $0.seasonNumber > $1.seasonNumber }
                    .prefix(4)

                for season in seasons {
                    let response = try await service.seasonDetails(
                        seriesID: entry.tmdbID,
                        seasonNumber: season.seasonNumber
                    )
                    for episode in response.episodes {
                        guard let date = Self.parseDate(episode.airDate), date >= start, date <= end else { continue }
                        found.append(BingeReleaseItem(
                            id: "episode-\(entry.tmdbID)-\(episode.id)",
                            title: entry.title,
                            detail: "S\(episode.seasonNumber) · E\(episode.episodeNumber)  \(episode.name)",
                            date: date,
                            kind: .episode,
                            posterPath: entry.posterPath
                        ))
                    }
                }
            } catch {
                if fetchError == nil {
                    fetchError = error.localizedDescription
                }
            }
        }

        releases = found.sorted { $0.date < $1.date }
        if releases.isEmpty {
            errorMessage = fetchError
        }
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
