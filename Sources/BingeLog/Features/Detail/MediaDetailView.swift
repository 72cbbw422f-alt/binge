import SwiftData
import SwiftUI

struct MediaDetailView: View {
    let id: Int
    let mediaKind: BingeMediaKind
    let fallbackTitle: String
    let fallbackOverview: String
    let fallbackPosterPath: String?
    let fallbackBackdropPath: String?

    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [BingeEntry]
    @Query private var episodeProgress: [BingeEpisodeProgress]
    @State private var expandedSeason: Int?
    @State private var loadedSeasons: [Int: [TMDBEpisode]] = [:]
    @State private var loadingSeason: Int?
    @State private var details: TMDBDetailResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedRating = 0.0
    @State private var persistenceError: String?
    @State private var episodeUpdatesInFlight: Set<String> = []

    private let service = TMDBService()

    private var savedEntry: BingeEntry? {
        entries.first { $0.tmdbID == id && $0.mediaKind == mediaKind }
    }

    private var retainedWatchedEpisodeCount: Int {
        guard mediaKind == .tv else { return 0 }
        return Set<String>(episodeProgress.compactMap { (item: BingeEpisodeProgress) -> String? in
            guard item.seriesTMDBID == id, item.isWatched else { return nil }
            return "\(item.seasonNumber)-\(item.episodeNumber)"
        }).count
    }

    private var title: String { details?.displayTitle ?? fallbackTitle }
    private var overview: String {
        let value = details?.overview ?? fallbackOverview
        return value.isEmpty ? "Ingen beskrivning finns tillgänglig." : value
    }
    private var posterURL: URL? {
        if let path = details?.posterPath {
            return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
        }
        guard let fallbackPosterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(fallbackPosterPath)")
    }
    private var backdropURL: URL? {
        if let path = details?.backdropPath {
            return URL(string: "https://image.tmdb.org/t/p/w1280\(path)")
        }
        guard let fallbackBackdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\(fallbackBackdropPath)")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        tag(mediaKind.title.uppercased(), color: BingeTheme.accent)
                        if let year = details?.year { tag(year, color: BingeTheme.secondaryText) }
                        if let rating = details?.voteAverage, rating > 0 {
                            Label(rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(hex: 0xF5B94C))
                        }
                    }
                    Text(title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let genres = details?.genres, !genres.isEmpty {
                        Text(genres.map(\.name).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(BingeTheme.secondaryText)
                    }
                    if let duration = details?.durationText {
                        Label(duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(BingeTheme.secondaryText)
                    }
                }
                .padding(.horizontal, BingeTheme.screenPadding)

                actionPanel
                synopsis
                if mediaKind == .tv {
                    seriesProgressSection
                    seasonsSection
                }
                castSection
                trailerSection
                if let errorMessage { errorNotice }
                attribution
            }
            .padding(.bottom, 32)
        }
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task(id: id) { await loadDetails() }
        .onAppear { selectedRating = savedEntry?.userRating ?? 0 }
        .onChange(of: savedEntry?.userRating) { _, value in selectedRating = value ?? 0 }
        .alert("Kunde inte spara ändringen", isPresented: Binding(get: { persistenceError != nil }, set: { if !$0 { persistenceError = nil } })) {
            Button("OK", role: .cancel) { persistenceError = nil }
        } message: {
            Text(persistenceError ?? "Försök igen.")
        }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            if let backdropURL {
                AsyncImage(url: backdropURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        BingeTheme.elevated
                    }
                }
                .frame(height: 260)
                .clipped()
            } else {
                BingeTheme.elevated.frame(height: 260)
            }
            LinearGradient(colors: [.clear, BingeTheme.background], startPoint: .center, endPoint: .bottom)
            HStack(alignment: .bottom, spacing: 14) {
                AsyncImage(url: posterURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        ZStack {
                            BingeTheme.elevated
                            Image(systemName: "film").foregroundStyle(BingeTheme.secondaryText)
                        }
                    }
                }
                .frame(width: 104, height: 154)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.12), lineWidth: 1))
                Spacer()
                if isLoading {
                    ProgressView().tint(BingeTheme.accent).padding(.bottom, 12)
                }
            }
            .padding(.horizontal, BingeTheme.screenPadding)
            .padding(.bottom, 4)
        }
        .frame(height: 260)
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let savedEntry {
                Menu {
                    ForEach(BingeWatchStatus.allCases) { status in
                        Button {
                            updateStatus(savedEntry, to: status)
                        } label: {
                            Label(status.title, systemImage: status.symbol)
                        }
                    }
                } label: {
                    HStack {
                        Label(savedEntry.status.title, systemImage: savedEntry.status.symbol)
                            .font(.headline)
                        Spacer()
                        Text("Ändra status")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.down").font(.caption)
                    }
                    .foregroundStyle(statusColor(savedEntry.status))
                    .padding(14)
                    .background(statusColor(savedEntry.status).opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
                }
            } else {
                Button {
                    let entry = BingeEntry(
                        tmdbID: id,
                        mediaKind: mediaKind,
                        title: title,
                        posterPath: details?.posterPath ?? fallbackPosterPath,
                        backdropPath: details?.backdropPath ?? fallbackBackdropPath,
                        overview: details?.overview ?? fallbackOverview,
                        releaseDate: details?.releaseDate ?? details?.firstAirDate,
                        tmdbRating: details?.voteAverage,
                        status: .planned
                    )
                    performPersistence { context in
                        context.insert(entry)
                    }
                } label: {
                    Label(
                        retainedWatchedEpisodeCount > 0 ? "Lägg tillbaka i samlingen" : "Lägg till i Vill se",
                        systemImage: retainedWatchedEpisodeCount > 0 ? "arrow.uturn.backward" : "bookmark.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BingeTheme.accent, in: RoundedRectangle(cornerRadius: 13))
                    .foregroundStyle(.black)
                }
                .buttonStyle(.plain)

                if retainedWatchedEpisodeCount > 0 {
                    Label(
                        "\(retainedWatchedEpisodeCount) tidigare sedda avsnitt finns kvar",
                        systemImage: "checkmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(BingeTheme.accent)
                }
            }

            if savedEntry != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Ditt betyg")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(selectedRating == 0 ? "Inte betygsatt" : selectedRating.formatted(.number.precision(.fractionLength(1))) + "/10")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(hex: 0xF5B94C))
                    }
                    Slider(
                        value: $selectedRating,
                        in: 0...10,
                        step: 0.5,
                        onEditingChanged: { isEditing in
                            guard !isEditing else { return }
                            setUserRating(selectedRating == 0 ? nil : selectedRating)
                        }
                    )
                    .tint(Color(hex: 0xF5B94C))
                    HStack {
                        Text("Tryck och dra för att sätta betyg")
                        Spacer()
                        Button("Nollställ") {
                            selectedRating = 0
                            setUserRating(nil)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(BingeTheme.secondaryText)
                }
                .padding(14)
                .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 13))
            }
        }
        .padding(.horizontal, BingeTheme.screenPadding)
    }

    private var synopsis: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("Om \(mediaKind == .movie ? "filmen" : "serien")")
            Text(overview)
                .font(.subheadline)
                .foregroundStyle(BingeTheme.secondaryText)
                .lineSpacing(4)
        }
        .padding(.horizontal, BingeTheme.screenPadding)
    }

    private var seriesProgressSection: some View {
        let seasons = details?.seasons?.filter { $0.seasonNumber > 0 } ?? []
        let totalEpisodes = seasons.reduce(0) { $0 + $1.episodeCount }
        let watchedEpisodes = Set<String>(episodeProgress.compactMap { (item: BingeEpisodeProgress) -> String? in
            guard item.seriesTMDBID == id, item.isWatched, item.seasonNumber > 0 else { return nil }
            return "\(item.seasonNumber)-\(item.episodeNumber)"
        }).count
        let progress = totalEpisodes > 0 ? Double(watchedEpisodes) / Double(totalEpisodes) : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("Ditt serieframsteg")
                Spacer()
                Text("\(watchedEpisodes) av \(totalEpisodes) avsnitt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BingeTheme.accent)
            }
            ProgressView(value: progress)
                .tint(BingeTheme.accent)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
            Text(totalEpisodes == 0 ? "Avsnittsdata är inte tillgänglig ännu." : "\(Int(progress * 100)) % av serien markerad som sedd")
                .font(.caption)
                .foregroundStyle(BingeTheme.secondaryText)
        }
        .padding(14)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, BingeTheme.screenPadding)
    }

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Säsonger och avsnitt")
            if let seasons = details?.seasons?.filter({ $0.seasonNumber > 0 }), !seasons.isEmpty {
                ForEach(seasons) { season in
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            Task { await toggleSeason(season.seasonNumber) }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(season.name).font(.headline).foregroundStyle(.white)
                                    let watched = Set<Int>(episodeProgress.compactMap { (item: BingeEpisodeProgress) -> Int? in
                                        guard item.seriesTMDBID == id, item.seasonNumber == season.seasonNumber, item.isWatched else { return nil }
                                        return item.episodeNumber
                                    }).count
                                    Text("\(watched) av \(season.episodeCount) avsnitt sedda").font(.caption).foregroundStyle(BingeTheme.secondaryText)
                                }
                                Spacer()
                                if loadingSeason == season.seasonNumber { ProgressView().tint(BingeTheme.accent) }
                                else { Image(systemName: expandedSeason == season.seasonNumber ? "chevron.up" : "chevron.down").foregroundStyle(BingeTheme.accent) }
                            }
                            .padding(13)
                            .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        if expandedSeason == season.seasonNumber {
                            ForEach(loadedSeasons[season.seasonNumber] ?? []) { episode in
                                episodeRow(episode)
                            }
                        }
                    }
                }
            } else {
                Text("Säsongsinformation saknas.").font(.caption).foregroundStyle(BingeTheme.secondaryText)
            }
        }
        .padding(.horizontal, BingeTheme.screenPadding)
    }

    private func episodeRow(_ episode: TMDBEpisode) -> some View {
        let matchingProgress = episodeProgress.filter {
            $0.seriesTMDBID == id && $0.seasonNumber == episode.seasonNumber && $0.episodeNumber == episode.episodeNumber
        }
        let isWatched = matchingProgress.contains { $0.isWatched }
        let progressKey = "\(id)-\(episode.seasonNumber)-\(episode.episodeNumber)"
        let isUpdating = episodeUpdatesInFlight.contains(progressKey)
        return HStack(spacing: 10) {
            if let url = episode.stillURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { BingeTheme.elevated }
                }
                .frame(width: 92, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            } else {
                RoundedRectangle(cornerRadius: 7).fill(BingeTheme.elevated).frame(width: 92, height: 54)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("AVSNITT \(episode.episodeNumber)").font(.caption2.weight(.bold)).foregroundStyle(BingeTheme.accent)
                Text(episode.name).font(.caption.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
            }
            Spacer()
            Button {
                toggleEpisode(episode)
            } label: {
                Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isWatched ? BingeTheme.accent : BingeTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .disabled(isUpdating)
            .accessibilityLabel(isWatched ? "Markera som ej sett" : "Markera som sett")
        }
        .padding(9)
        .background(BingeTheme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
    }

    private func toggleSeason(_ season: Int) async {
        if expandedSeason == season {
            expandedSeason = nil
            return
        }
        expandedSeason = season
        guard loadedSeasons[season] == nil else { return }
        loadingSeason = season
        defer { loadingSeason = nil }
        do {
            let response = try await service.seasonDetails(seriesID: id, seasonNumber: season)
            loadedSeasons[season] = response.episodes.sorted { $0.episodeNumber < $1.episodeNumber }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleEpisode(_ episode: TMDBEpisode) {
        let progressKey = "\(id)-\(episode.seasonNumber)-\(episode.episodeNumber)"
        guard episodeUpdatesInFlight.insert(progressKey).inserted else { return }
        defer { episodeUpdatesInFlight.remove(progressKey) }

        performPersistence { context in
            let seriesID = id
            let seasonNumber = episode.seasonNumber
            let episodeNumber = episode.episodeNumber
            let descriptor = FetchDescriptor<BingeEpisodeProgress>(
                predicate: #Predicate {
                    $0.seriesTMDBID == seriesID &&
                    $0.seasonNumber == seasonNumber &&
                    $0.episodeNumber == episodeNumber
                }
            )
            let matchingProgress = try context.fetch(descriptor)
            let wasWatched = matchingProgress.contains { $0.isWatched }

            if !matchingProgress.isEmpty {
                // Keep legacy duplicate rows consistent without deleting stored progress records.
                for item in matchingProgress {
                    item.watchedAt = wasWatched ? nil : .now
                }
            } else {
                let item = BingeEpisodeProgress(
                    seriesTMDBID: seriesID,
                    seasonNumber: seasonNumber,
                    episodeNumber: episodeNumber,
                    episodeName: episode.name
                )
                item.watchedAt = .now
                context.insert(item)
            }

            context.insert(BingeWatchEvent(
                type: wasWatched ? .episodeUnwatched : .episodeWatched,
                tmdbID: seriesID,
                mediaKind: .tv,
                title: title,
                detail: "S\(seasonNumber) · A\(episodeNumber) – \(episode.name)"
            ))
        }
    }

    private var castSection: some View {
        Group {
            if let cast = details?.credits?.cast, !cast.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("Medverkande")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(cast.prefix(12)) { member in
                                VStack(alignment: .leading, spacing: 6) {
                                    AsyncImage(url: member.profileURL) { phase in
                                        if let image = phase.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            ZStack {
                                                BingeTheme.elevated
                                                Image(systemName: "person.fill").foregroundStyle(BingeTheme.secondaryText)
                                            }
                                        }
                                    }
                                    .frame(width: 82, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Text(member.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                        .frame(width: 82, alignment: .leading)
                                    if let character = member.character {
                                        Text(character)
                                            .font(.caption2)
                                            .foregroundStyle(BingeTheme.secondaryText)
                                            .lineLimit(2)
                                            .frame(width: 82, alignment: .leading)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, BingeTheme.screenPadding)
                    }
                    .contentMargins(.horizontal, -BingeTheme.screenPadding)
                }
            }
        }
    }

    private var trailerSection: some View {
        Group {
            if let trailer = details?.videos?.results.first(where: { $0.type == "Trailer" && $0.site == "YouTube" }),
               let url = trailer.youtubeURL {
                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Trailer")
                    Link(destination: url) {
                        HStack(spacing: 12) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.title2)
                                .foregroundStyle(BingeTheme.accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(trailer.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white).lineLimit(2)
                                Text("Öppna på YouTube").font(.caption).foregroundStyle(BingeTheme.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").foregroundStyle(BingeTheme.secondaryText)
                        }
                        .padding(14)
                        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 13))
                    }
                }
                .padding(.horizontal, BingeTheme.screenPadding)
            }
        }
    }

    private var attribution: some View {
        Text("Information och bilder från TMDB. Denna produkt använder TMDB API men är inte godkänd eller certifierad av TMDB.")
            .font(.caption2)
            .foregroundStyle(BingeTheme.secondaryText)
            .padding(.horizontal, BingeTheme.screenPadding)
    }

    private var errorNotice: some View {
        Text(errorMessage ?? "")
            .font(.caption)
            .foregroundStyle(Color(hex: 0xF07878))
    }

    private func loadDetails() async {
        do {
            details = try await service.details(id: id, mediaKind: mediaKind)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func updateStatus(_ entry: BingeEntry, to status: BingeWatchStatus) {
        let entryID = entry.tmdbID
        let mediaKindRaw = entry.mediaKind.rawValue
        performPersistence { context in
            let descriptor = FetchDescriptor<BingeEntry>(
                predicate: #Predicate {
                    $0.tmdbID == entryID && $0.mediaKindRaw == mediaKindRaw
                }
            )
            guard let target = try context.fetch(descriptor).first else {
                throw DetailPersistenceError.entryNotFound
            }

            let previousStatus = target.status
            guard previousStatus != status else { return }
            context.insert(BingeWatchEvent(
                type: .statusChanged,
                tmdbID: target.tmdbID,
                mediaKind: target.mediaKind,
                title: target.title,
                detail: "\(previousStatus.title) → \(status.title)"
            ))
            target.status = status
            switch status {
            case .watching:
                if target.startedAt == nil { target.startedAt = .now }
                target.completedAt = nil
            case .completed:
                target.completedAt = .now
                if target.startedAt == nil { target.startedAt = target.addedAt }
            case .planned, .onHold, .dropped:
                target.completedAt = nil
            }
        }
    }

    private func setUserRating(_ rating: Double?) {
        let entryID = id
        let mediaKindRaw = mediaKind.rawValue
        performPersistence { context in
            let descriptor = FetchDescriptor<BingeEntry>(
                predicate: #Predicate {
                    $0.tmdbID == entryID && $0.mediaKindRaw == mediaKindRaw
                }
            )
            guard let target = try context.fetch(descriptor).first else {
                throw DetailPersistenceError.entryNotFound
            }
            target.userRating = rating
            target.updatedAt = .now
        }
    }

    private func performPersistence(_ operation: (ModelContext) throws -> Void) {
        do {
            try DetailViewPersistence.perform(in: modelContext.container, operation)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    private func statusColor(_ status: BingeWatchStatus) -> Color {
        switch status {
        case .planned: Color(hex: 0x68A9FF)
        case .watching: BingeTheme.accent
        case .completed: Color(hex: 0x42D6A4)
        case .onHold: Color(hex: 0xF5B94C)
        case .dropped: Color(hex: 0xF07878)
        }
    }

    private func tag(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.13), in: Capsule())
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(.white)
    }
}


private enum DetailPersistenceError: LocalizedError {
    case entryNotFound

    var errorDescription: String? {
        "Titeln finns inte längre i samlingen."
    }
}
