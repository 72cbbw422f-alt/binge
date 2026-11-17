import SwiftData
import SwiftUI

struct MDBListImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var savedEntries: [BingeEntry]
    @State private var apiKey = SecureTokenStore.read(service: "BingeLog.MDBList") ?? ""
    @State private var lists: [MDBListUserList] = []
    @State private var selectedListID: Int?
    @State private var isLoading = false
    @State private var isImporting = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var showDisconnectConfirmation = false
    private let service = MDBListService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("IMPORTERA")
                        .font(.caption.weight(.bold)).tracking(1.5)
                        .foregroundStyle(BingeTheme.accent)
                    Text("MDBList")
                        .font(.largeTitle.bold()).foregroundStyle(.white)
                    Text("Hämta dina egna listor till BingeLog. Importen lägger till saknade titlar och lämnar din personliga tittstatus och dina betyg ifred.")
                        .font(.subheadline).foregroundStyle(BingeTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("API-NYCKEL").font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(BingeTheme.secondaryText)
                    SecureField("Klistra in MDBList API-nyckel", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(13)
                        .background(BingeTheme.elevated, in: RoundedRectangle(cornerRadius: 12))
                    HStack {
                        Link("Hämta API-nyckel", destination: URL(string: "https://mdblist.com/preferences/#api")!)
                            .font(.footnote)
                        Spacer()
                        Button("Spara nyckel") {
                            let saved = SecureTokenStore.save(apiKey, service: "BingeLog.MDBList")
                            statusMessage = saved ? "API-nyckeln sparad säkert." : "Kunde inte spara API-nyckeln."
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(BingeTheme.accent)
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if SecureTokenStore.read(service: "BingeLog.MDBList") != nil {
                        Button("Koppla från MDBList", role: .destructive) {
                            showDisconnectConfirmation = true
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
                .padding(16)
                .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                Button {
                    Task { await loadLists() }
                } label: {
                    HStack {
                        if isLoading { ProgressView().tint(.black) }
                        Text(isLoading ? "Hämtar listor…" : "Hämta mina MDBList-listor")
                        Spacer()
                        Image(systemName: "arrow.down.circle")
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .padding(15)
                    .background(BingeTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isLoading || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !lists.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("VÄLJ LISTA").font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(BingeTheme.secondaryText)
                        ForEach(lists) { list in
                            Button {
                                selectedListID = list.id
                                statusMessage = nil
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "list.bullet.rectangle")
                                        .foregroundStyle(BingeTheme.accent)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(list.name).font(.headline).foregroundStyle(.white)
                                        Text("\(list.itemCount ?? 0) titlar")
                                            .font(.caption).foregroundStyle(BingeTheme.secondaryText)
                                    }
                                    Spacer()
                                    if selectedListID == list.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(BingeTheme.accent)
                                    } else {
                                        Image(systemName: "circle").foregroundStyle(BingeTheme.secondaryText)
                                    }
                                }
                                .padding(13)
                                .background(selectedListID == list.id ? BingeTheme.accent.opacity(0.12) : BingeTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote).foregroundStyle(.red)
                }
                if let statusMessage {
                    Label(statusMessage, systemImage: "checkmark.circle.fill")
                        .font(.footnote).foregroundStyle(BingeTheme.accent)
                }

                if selectedListID != nil {
                    Button {
                        Task { await importSelectedList() }
                    } label: {
                        HStack {
                            if isImporting { ProgressView().tint(.black) }
                            Text(isImporting ? "Importerar…" : "Importera vald lista")
                            Spacer()
                            Image(systemName: "square.and.arrow.down")
                        }
                        .font(.headline).foregroundStyle(.black).padding(15)
                        .background(BingeTheme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isImporting)
                }

                Text("BingeLog använder TMDB-ID för säker matchning. Titlar utan TMDB-ID hoppas över i stället för att riskera felaktiga dubbletter. Importen är begränsad till 1 000 poster per lista enligt MDBLists API.")
                    .font(.caption).foregroundStyle(BingeTheme.secondaryText)
            }
            .padding(BingeTheme.screenPadding)
        }
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Koppla från MDBList?",
            isPresented: $showDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button("Koppla från och ta bort nyckeln", role: .destructive) {
                SecureTokenStore.delete(service: "BingeLog.MDBList")
                apiKey = ""
                lists = []
                selectedListID = nil
                statusMessage = "MDBList-nyckeln har tagits bort. Importerade titlar finns kvar i BingeLog."
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Endast den sparade API-nyckeln tas bort. Filmer, serier, betyg och tittarhistorik i BingeLog påverkas inte.")
        }
    }

    @MainActor
    private func loadLists() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        statusMessage = nil
        do {
            SecureTokenStore.save(apiKey, service: "BingeLog.MDBList")
            lists = try await service.userLists(apiKey: apiKey)
            if lists.isEmpty { statusMessage = "Inga egna listor hittades på kontot." }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importSelectedList() async {
        guard let selectedListID else { return }
        isImporting = true
        defer { isImporting = false }
        errorMessage = nil
        statusMessage = nil
        do {
            let items = try await service.listItems(listID: selectedListID, apiKey: apiKey)
            var added = 0
            var skipped = 0
            // Skip duplicates both in SwiftData and within the imported list.
            var knownKeys = Set(savedEntries.map { "\($0.mediaKind.rawValue)-\($0.tmdbID)" })
            for item in items {
                guard let tmdbID = item.tmdbID,
                      let title = item.title,
                      let rawType = item.importMediaType else {
                    skipped += 1
                    continue
                }
                let kind: BingeMediaKind = rawType == "movie" ? .movie : .tv
                let key = "\(kind.rawValue)-\(tmdbID)"
                guard knownKeys.insert(key).inserted else {
                    skipped += 1
                    continue
                }
                let date = item.year.map { String($0) + "-01-01" }
                let entry = BingeEntry(
                    tmdbID: tmdbID,
                    mediaKind: kind,
                    title: title,
                    posterPath: normalizedPosterPath(item.poster),
                    overview: item.overview ?? "",
                    releaseDate: date,
                    status: .planned
                )
                modelContext.insert(entry)
                added += 1
            }
            try modelContext.save()
            statusMessage = "Klart! \(added) nya titlar importerades. \(skipped) poster hoppades över och befintliga titlar lämnades orörda."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func normalizedPosterPath(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if value.hasPrefix("http"), let url = URL(string: value) {
            return url.path
        }
        return value.hasPrefix("/") ? value : "/" + value
    }
}
