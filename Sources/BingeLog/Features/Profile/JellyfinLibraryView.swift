import SwiftData
import SwiftUI

struct JellyfinLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var savedEntries: [BingeEntry]
    @State private var items: [JellyfinLibraryItem] = []
    @State private var isLoading = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("JELLYFIN")
                        .font(.caption.weight(.bold)).tracking(1.5)
                        .foregroundStyle(BingeTheme.accent)
                    Text("Ditt bibliotek")
                        .font(.largeTitle.bold()).foregroundStyle(.white)
                    Text("Hämta filmer och serier från din mediaserver. Bara titlar med TMDB-ID kan matchas säkert mot BingeLog.")
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
                .disabled(isLoading || isImporting)

                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MATCHNING")
                            .font(.caption.weight(.bold)).tracking(1.2)
                            .foregroundStyle(BingeTheme.secondaryText)
                        summaryRow("Redan sparade", value: matchedItems.count, symbol: "checkmark.circle")
                        summaryRow("Nya att importera", value: importableItems.count, symbol: "plus.circle")
                        summaryRow("Saknar TMDB-ID", value: withoutTMDB, symbol: "questionmark.circle")
                    }
                    .padding(15)
                    .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                    if importableItems.count > 0 {
                        Button {
                            importNewItems()
                        } label: {
                            HStack {
                                if isImporting { ProgressView().tint(.black) }
                                Text(isImporting ? "Importerar…" : "Importera \(importableItems.count) nya titlar")
                                Spacer()
                                Image(systemName: "square.and.arrow.down")
                            }
                            .font(.headline).foregroundStyle(.black).padding(15)
                            .background(BingeTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isImporting)
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
                                if item.tmdbID == nil {
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
                                        Text("Saknar ID").font(.caption2).foregroundStyle(BingeTheme.secondaryText)
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
    private func importNewItems() {
        var added = 0
        for item in importableItems {
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
            added += 1
        }
        do {
            try modelContext.save()
            statusMessage = "Klart! \(added) nya titlar importerades som Vill se. Befintliga betyg och tittarhistorik ändrades inte."
        } catch {
            errorMessage = "Importen kunde inte sparas: \(error.localizedDescription)"
        }
    }
}
