import SwiftData
import SwiftUI

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var savedEntries: [BingeEntry]
    @State private var query = ""
    @State private var results: [TMDBMediaItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showTokenSheet = false
    @State private var persistenceError: String?
    private let service = TMDBService()

    private var hasToken: Bool {
        SecureTokenStore.read(service: "BingeLog.TMDB") != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(BingeTheme.secondaryText)
                    TextField("Sök filmer, serier och personer", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button {
                            query = ""
                            results = []
                            errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(BingeTheme.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Rensa sökning")
                    }
                }
                .padding(15)
                .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 15))

                if !hasToken {
                    connectionPrompt
                } else if isLoading {
                    ProgressView("Söker i TMDB…")
                        .tint(BingeTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                } else if let errorMessage {
                    ContentUnavailableView("Sökningen misslyckades", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                        .foregroundStyle(.white)
                } else if !query.isEmpty && results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .foregroundStyle(.white)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(results) { item in
                            resultRow(item)
                        }
                    }
                }

                if hasToken && query.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("UPPTÄCK DIN NÄSTA FAVORIT")
                            .font(.caption.weight(.bold))
                            .tracking(1.3)
                            .foregroundStyle(BingeTheme.accent)
                        Text("Sök bland filmer och serier från hela världen.")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Resultaten hämtas från TMDB med svenska titlar och metadata där det finns tillgängligt.")
                            .font(.subheadline)
                            .foregroundStyle(BingeTheme.secondaryText)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(BingeTheme.screenPadding)
        }
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: query) {
            let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard term.count >= 2, hasToken else {
                results = []
                errorMessage = nil
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(350))
                isLoading = true
                defer { isLoading = false }
                let response = try await service.searchMulti(query: term)
                try Task.checkCancellation()
                results = response.results.filter { $0.mediaType == .movie || $0.mediaType == .tv }
                errorMessage = nil
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showTokenSheet) {
            TMDBTokenSheet()
        }
        .alert("Kunde inte spara titeln", isPresented: Binding(get: { persistenceError != nil }, set: { if !$0 { persistenceError = nil } })) {
            Button("OK", role: .cancel) { persistenceError = nil }
        } message: {
            Text(persistenceError ?? "Försök igen.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("UPPTÄCK")
                    .font(.caption.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(BingeTheme.accent)
                Text("Hitta något bra.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                showTokenSheet = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(BingeTheme.surface, in: Circle())
            }
            .accessibilityLabel("TMDB-inställningar")
        }
    }

    private var connectionPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 30))
                .foregroundStyle(BingeTheme.accent)
            Text("Anslut TMDB")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("BingeLog använder TMDB för att hämta filmer, serier, bilder och premiärinformation. Din API Read Access Token sparas säkert i iPhones nyckelring.")
                .font(.subheadline)
                .foregroundStyle(BingeTheme.secondaryText)
            Button("Lägg till API-token") {
                showTokenSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(BingeTheme.accent)
            .foregroundStyle(.black)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private func resultRow(_ item: TMDBMediaItem) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                MediaDetailView(
                    id: item.id,
                    mediaKind: item.mediaType == .tv ? .tv : .movie,
                    fallbackTitle: item.displayTitle,
                    fallbackOverview: item.overview ?? "",
                    fallbackPosterPath: item.posterPath,
                    fallbackBackdropPath: item.backdropPath
                )
            } label: {
                HStack(spacing: 12) {
                    AsyncImage(url: item.posterURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            posterPlaceholder
                        }
                    }
                    .frame(width: 76, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.displayTitle)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        HStack(spacing: 8) {
                            Text(item.mediaType?.displayName ?? "TITEL")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(BingeTheme.accent)
                            if let year = item.year {
                                Text(year).font(.caption).foregroundStyle(BingeTheme.secondaryText)
                            }
                            if let rating = item.rating {
                                Label(rating, systemImage: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(BingeTheme.secondaryText)
                            }
                        }
                        if let overview = item.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.caption)
                                .foregroundStyle(BingeTheme.secondaryText)
                                .lineLimit(3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Button {
                save(item)
            } label: {
                Image(systemName: isSaved(item) ? "checkmark" : "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSaved(item) ? BingeTheme.accent : .black)
                    .frame(width: 38, height: 38)
                    .background(isSaved(item) ? BingeTheme.accent.opacity(0.14) : BingeTheme.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(isSaved(item))
            .accessibilityLabel(isSaved(item) ? "Redan sparad" : "Lägg till i samlingen")
        }
        .padding(10)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private func isSaved(_ item: TMDBMediaItem) -> Bool {
        savedEntries.contains {
            $0.tmdbID == item.id && $0.mediaKind.rawValue == item.mediaType?.rawValue
        }
    }

    private func save(_ item: TMDBMediaItem) {
        guard let type = item.mediaType, type == .movie || type == .tv, !isSaved(item) else { return }
        let entry = BingeEntry(
            tmdbID: item.id,
            mediaKind: type == .movie ? .movie : .tv,
            title: item.displayTitle,
            originalTitle: item.originalTitle ?? item.originalName ?? "",
            posterPath: item.posterPath,
            backdropPath: item.backdropPath,
            overview: item.overview ?? "",
            releaseDate: item.releaseDate ?? item.firstAirDate,
            tmdbRating: item.voteAverage,
            status: .planned
        )
        modelContext.insert(entry)
        do {
            try modelContext.save()
            persistenceError = nil
        } catch {
            modelContext.rollback()
            persistenceError = error.localizedDescription
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            BingeTheme.elevated
            Image(systemName: "film")
                .font(.title2)
                .foregroundStyle(BingeTheme.secondaryText)
        }
    }
}

private struct TMDBTokenSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section("TMDB API Read Access Token") {
                    SecureField("Klistra in din Bearer-token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("Skapa eller hitta din token i TMDB-kontots API-inställningar. Den sparas endast lokalt i iPhones nyckelring och skickas direkt till TMDB vid sökning.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link("Öppna TMDB API-inställningar", destination: URL(string: "https://www.themoviedb.org/settings/api")!)
                }
                if saved {
                    Section {
                        Label("Token sparad", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                Section {
                    Button("Spara token") {
                        saved = SecureTokenStore.save(token, service: "BingeLog.TMDB")
                        if saved { dismiss() }
                    }
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Ta bort sparad token", role: .destructive) {
                        SecureTokenStore.delete(service: "BingeLog.TMDB")
                        dismiss()
                    }
                }
            }
            .navigationTitle("TMDB-anslutning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stäng") { dismiss() }
                }
            }
        }
    }
}
