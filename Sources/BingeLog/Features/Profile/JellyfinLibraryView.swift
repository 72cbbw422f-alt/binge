import SwiftData
import SwiftUI

struct JellyfinLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var savedEntries: [BingeEntry]
    @State private var items: [JellyfinLibraryItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var itemToMatch: JellyfinLibraryItem?
    private let service = JellyfinService()

    private var supportedItems: [JellyfinLibraryItem] {
        items.filter { $0.mediaKind != nil }
    }

    private var matchedItems: [JellyfinLibraryItem] {
        supportedItems.filter { item in
            guard let id = item.tmdbID, let kind = item.mediaKind else { return false }
            return savedEntries.contains { $0.tmdbID == id && $0.mediaKind == kind }
        }
    }

    private var importableItems: [JellyfinLibraryItem] {
        var known = Set(savedEntries.map { "\($0.mediaKind.rawValue)-\($0.tmdbID)" })
        return supportedItems.filter { item in
            guard let id = item.tmdbID, let kind = item.mediaKind else { return false }
            return known.insert("\(kind.rawValue)-\(id)").inserted
        }
    }

    private var itemsWithoutTMDB: [JellyfinLibraryItem] {
        supportedItems.filter { $0.tmdbID == nil }
    }

    private var withoutTMDB: Int { itemsWithoutTMDB.count }

    private var playedItems: [JellyfinLibraryItem] {
        supportedItems.filter { $0.userData?.played == true }
    }

    private var watchStateDifferences: [JellyfinWatchStateDifference] {
        supportedItems.compactMap { item in
            guard let id = item.tmdbID, let kind = item.mediaKind,
                  let local = savedEntries.first(where: { $0.tmdbID == id && $0.mediaKind == kind }) else { return nil }
            let jellyfinPlayed = item.userData?.played == true
            let localCompleted = local.status == .completed
            guard jellyfinPlayed != localCompleted else { return nil }
            return JellyfinWatchStateDifference(item: item, localStatus: local.status.title, jellyfinStatus: jellyfinPlayed ? "Markerad som sedd" : "Inte markerad som sedd")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("JELLYFIN")
                        .font(.caption.weight(.bold)).tracking(1.5)
                        .foregroundStyle(BingeTheme.accent)
                    Text("Ditt bibliotek")
                        .font(.largeTitle.bold()).foregroundStyle(.white)
                    Text("Hämta filmer och serier från din mediaserver. Se även vilka titlar Jellyfin markerat som sedda. Bara titlar med TMDB-ID kan matchas säkert mot BingeLog.")
                        .font(.subheadline).foregroundStyle(BingeTheme.secondaryText)
                }

                HStack(spacing: 10) {
                    metric(String(supportedItems.count), title: "I Jellyfin")
                    metric(String(matchedItems.count), title: "Redan i BingeLog")
                    metric(String(importableItems.count), title: "Nya träffar")
                }

                Button {
                    Task { await loadLibrary() }
                } label: {
                    HStack {
                        if isLoading { ProgressView().tint(.black) }
                        Text(isLoading ? "Hämtar bibliotek…" : "Uppdatera bibliotek")
                        Spacer()
                        Image(systemName: "arrow.clockwise")
                    }
                    .font(.headline).foregroundStyle(.black).padding(15)
                    .background(BingeTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isLoading)

                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MATCHNING")
                            .font(.caption.weight(.bold)).tracking(1.2)
                            .foregroundStyle(BingeTheme.secondaryText)
                        summaryRow("Redan sparade", value: matchedItems.count, symbol: "checkmark.circle")
                        summaryRow("Nya att importera", value: importableItems.count, symbol: "plus.circle")
                        summaryRow("Saknar TMDB-ID", value: withoutTMDB, symbol: "questionmark.circle")
                        summaryRow("Markerade som sedda i Jellyfin", value: playedItems.count, symbol: "eye")
                        summaryRow("Skillnader mot BingeLog", value: watchStateDifferences.count, symbol: "arrow.left.arrow.right")
                    }
                    .padding(15)
                    .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                    if importableItems.count > 0 {
                        Button {
                            importNewItems()
                        } label: {
                            HStack {
                                                Text("Importera \(importableItems.count) nya titlar")
                                Spacer()
                                Image(systemName: "square.and.arrow.down")
                            }
                            .font(.headline).foregroundStyle(.black).padding(15)
                            .background(BingeTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("FILMER OCH SERIER")
                            .font(.caption.weight(.bold)).tracking(1.2)
                            .foregroundStyle(BingeTheme.secondaryText)
                        LazyVStack(spacing: 10) {
                            ForEach(supportedItems) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.mediaKind == .movie ? "film" : "tv")
                                    .foregroundStyle(BingeTheme.accent)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                    Text([item.mediaKind?.title, item.productionYear.map(String.init)].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(BingeTheme.secondaryText)
                                }
                                Spacer()
                                if item.userData?.played == true {
                                    Label("Sedd", systemImage: "checkmark.circle.fill")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(BingeTheme.accent)
                                } else if item.tmdbID == nil {
                                    Text("Saknar ID").font(.caption2).foregroundStyle(BingeTheme.secondaryText)
                                } else if let id = item.tmdbID, let kind = item.mediaKind,
                                          savedEntries.contains(where: { $0.tmdbID == id && $0.mediaKind == kind }) {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(BingeTheme.accent)
                                } else {
                                    Image(systemName: "plus.circle").foregroundStyle(BingeTheme.secondaryText)
                                }
                            }
                            .padding(11)
                            .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    if !watchStateDifferences.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SKILLNADER I TITTARSTATUS")
                                .font(.caption.weight(.bold)).tracking(1.2)
                                .foregroundStyle(BingeTheme.secondaryText)
                            Text("Jämförelsen är bara ett underlag. Inga statusar ändras i BingeLog.")
                                .font(.caption).foregroundStyle(BingeTheme.secondaryText)
                            ForEach(watchStateDifferences) { difference in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(difference.item.name)
                                        .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                    HStack {
                                        Text("BingeLog: \(difference.localStatus)")
                                        Spacer()
                                        Text("Jellyfin: \(difference.jellyfinStatus)")
                                    }
                                    .font(.caption).foregroundStyle(BingeTheme.secondaryText)
                                }
                                .padding(11)
                                .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    if !itemsWithoutTMDB.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("BEHÖVER MATCHAS")
                                .font(.caption.weight(.bold)).tracking(1.2)
                                .foregroundStyle(BingeTheme.secondaryText)
                            Text("De här titlarna saknar TMDB-ID i Jellyfin. De importeras inte automatiskt eftersom det finns risk att fel film eller serie kopplas.")
                                .font(.caption).foregroundStyle(BingeTheme.secondaryText)
                            LazyVStack(spacing: 8) {
                                ForEach(itemsWithoutTMDB) { item in
                                    HStack(spacing: 10) {
                                        Image(systemName: item.mediaKind == .movie ? "film" : "tv")
                                            .foregroundStyle(BingeTheme.secondaryText).frame(width: 30)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                            Text(item.mediaKind?.title ?? "Okänd typ").font(.caption).foregroundStyle(BingeTheme.secondaryText)
                                        }
                                        Spacer()
                                        Button("Matcha") { itemToMatch = item }
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(BingeTheme.accent)
                                    }
                                    .padding(11)
                                    .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                } else if !isLoading {
                    Text("Hämta biblioteket för att se vilka filmer och serier som kan importeras.")
                        .font(.subheadline).foregroundStyle(BingeTheme.secondaryText)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red)
                }
                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .font(.footnote).foregroundStyle(BingeTheme.accent)
                }
            }
            .padding(BingeTheme.screenPadding)
        }
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $itemToMatch) { item in
            JellyfinTMDBMatchSheet(item: item) { match in
                if importMatchedItem(item, match: match) {
                    itemToMatch = nil
                }
            }
        }
        .task {
            if items.isEmpty && SecureTokenStore.read(service: "BingeLog.Jellyfin.Token") != nil {
                await loadLibrary()
            }
        }
    }

    private func metric(_ value: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold()).foregroundStyle(.white)
            Text(title).font(.caption2).foregroundStyle(BingeTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 13))
    }

    private func summaryRow(_ title: String, value: Int, symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol).font(.subheadline).foregroundStyle(BingeTheme.secondaryText)
            Spacer()
            Text(String(value)).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
        }
    }

    @MainActor
    private func loadLibrary() async {
        isLoading = true
        errorMessage = nil
        statusMessage = nil
        defer { isLoading = false }
        do {
            items = try await service.libraryItems()
            statusMessage = "Hämtade \(supportedItems.count) filmer och serier från Jellyfin."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importMatchedItem(_ jellyfinItem: JellyfinLibraryItem, match: TMDBMediaItem) -> Bool {
        guard let kind = jellyfinItem.mediaKind,
              let mediaType = match.mediaType,
              (kind == .movie && mediaType == .movie) || (kind == .tv && mediaType == .tv),
              !savedEntries.contains(where: { $0.tmdbID == match.id && $0.mediaKind == kind }) else {
            errorMessage = "Titeln kunde inte matchas eller finns redan i BingeLog."
            return false
        }
        let entry = BingeEntry(
            tmdbID: match.id,
            mediaKind: kind,
            title: match.displayTitle,
            originalTitle: match.originalTitle ?? match.originalName ?? "",
            posterPath: match.posterPath,
            backdropPath: match.backdropPath,
            overview: match.overview ?? jellyfinItem.overview ?? "",
            releaseDate: match.releaseDate ?? match.firstAirDate ?? jellyfinItem.productionYear.map { "\($0)-01-01" },
            tmdbRating: match.voteAverage,
            status: .planned
        )
        modelContext.insert(entry)
        do {
            try modelContext.save()
            statusMessage = "\(match.displayTitle) matchades och lades till i Vill se."
            errorMessage = nil
            return true
        } catch {
            modelContext.delete(entry)
            errorMessage = "Matchningen kunde inte sparas: \(error.localizedDescription)"
            return false
        }
    }

    @MainActor
    private func importNewItems() {
        let candidates = importableItems
        guard !candidates.isEmpty else { return }

        var insertedEntries: [BingeEntry] = []
        for item in candidates {
            guard let id = item.tmdbID, let kind = item.mediaKind else { continue }
            let date = item.productionYear.map { "\($0)-01-01" }
            let entry = BingeEntry(
                tmdbID: id,
                mediaKind: kind,
                title: item.name,
                overview: item.overview ?? "",
                releaseDate: date,
                status: .planned
            )
            modelContext.insert(entry)
            insertedEntries.append(entry)
        }

        do {
            try modelContext.save()
            statusMessage = "Klart! \(insertedEntries.count) nya titlar importerades som Vill se. Befintliga betyg och tittarhistorik ändrades inte."
            errorMessage = nil
        } catch {
            for entry in insertedEntries {
                modelContext.delete(entry)
            }
            modelContext.rollback()
            errorMessage = "Importen misslyckades och har återställts. Inga nya titlar har lagts till. \(error.localizedDescription)"
            statusMessage = nil
        }
    }}


private struct JellyfinTMDBMatchSheet: View {
    let item: JellyfinLibraryItem
    let onSelect: (TMDBMediaItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [TMDBMediaItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    private let service = TMDBService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Välj rätt TMDB-titel för \(item.name). Kontrollera årtal och typ innan du matchar.")
                    .font(.subheadline)
                    .foregroundStyle(BingeTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField("Sök titel", text: $query)
                    .textFieldStyle(.roundedBorder)
                if isLoading {
                    ProgressView("Söker i TMDB…").tint(BingeTheme.accent)
                }
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }
                List(results) { result in
                    Button {
                        onSelect(result)
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: result.posterURL) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    RoundedRectangle(cornerRadius: 7).fill(BingeTheme.elevated)
                                        .overlay(Image(systemName: "film").foregroundStyle(BingeTheme.secondaryText))
                                }
                            }
                            .frame(width: 48, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.displayTitle).font(.subheadline.weight(.semibold))
                                Text([result.mediaType?.displayName, result.year].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                                if let rating = result.rating {
                                    Label(rating, systemImage: "star.fill").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listRowBackground(BingeTheme.surface)
                }
                .listStyle(.plain)
            }
            .padding()
            .background(BingeTheme.background.ignoresSafeArea())
            .navigationTitle("Matcha mot TMDB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") { dismiss() }
                }
            }
            .task(id: query) {
                let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard term.count >= 2 else {
                    results = []
                    return
                }
                do {
                    try await Task.sleep(for: .milliseconds(350))
                    isLoading = true
                    defer { isLoading = false }
                    let response = try await service.searchMulti(query: term)
                    try Task.checkCancellation()
                    let expected = item.mediaKind == .movie ? TMDBMediaType.movie : TMDBMediaType.tv
                    results = response.results.filter { $0.mediaType == expected }
                    errorMessage = nil
                } catch is CancellationError {
                    return
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .onAppear { query = item.name }
        }
    }
}


private struct JellyfinWatchStateDifference: Identifiable {
    let item: JellyfinLibraryItem
    let localStatus: String
    let jellyfinStatus: String

    var id: String { item.id }
}
