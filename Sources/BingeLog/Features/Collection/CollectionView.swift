import SwiftData
import SwiftUI

struct CollectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BingeEntry.addedAt, order: .reverse) private var entries: [BingeEntry]
    @State private var selectedStatus: BingeWatchStatus?
    @State private var selectedKind: BingeMediaKind?
    @State private var searchText = ""
    @State private var sortOrder = "recent"
    @State private var entryPendingDeletion: BingeEntry?

    private var filteredEntries: [BingeEntry] {
        let filtered = entries.filter {
            (selectedStatus == nil || $0.status == selectedStatus) &&
            (selectedKind == nil || $0.mediaKind == selectedKind) &&
            (searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
             $0.title.localizedCaseInsensitiveContains(searchText.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        switch sortOrder {
        case "title": return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case "rating": return filtered.sorted {
            switch ($0.userRating, $1.userRating) {
            case let (left?, right?): return left > right
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
        default: return filtered.sorted { $0.addedAt > $1.addedAt }
        }
    }

    private var sortTitle: String {
        switch sortOrder {
        case "title": "Titel A–Ö"
        case "rating": "Betyg"
        default: "Senast tillagda"
        }
    }

    private func sortOption(_ title: String, value: String) -> some View {
        Button {
            sortOrder = value
        } label: {
            if sortOrder == value {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var visibleSections: [BingeWatchStatus] {
        if let selectedStatus { return [selectedStatus] }
        return [.watching, .planned, .completed, .onHold, .dropped]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                statusOverview

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(BingeTheme.secondaryText)
                    TextField("Sök i din samling", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(BingeTheme.secondaryText)
                        }
                        .accessibilityLabel("Rensa sökning")
                    }
                }
                .padding(13)
                .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, BingeTheme.screenPadding)

                HStack(spacing: 8) {
                    kindChip("Allt", kind: nil)
                    kindChip("Filmer", kind: .movie)
                    kindChip("Serier", kind: .tv)
                    Spacer(minLength: 0)
                    Menu {
                        sortOption("Senast tillagda", value: "recent")
                        sortOption("Titel A–Ö", value: "title")
                        sortOption("Högst personligt betyg", value: "rating")
                    } label: {
                        Label(sortTitle, systemImage: "arrow.up.arrow.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BingeTheme.accent)
                    }
                }

                ForEach(visibleSections) { status in
                    let sectionEntries = filteredEntries.filter { $0.status == status }
                    if !sectionEntries.isEmpty {
                        statusSection(status, items: sectionEntries)
                    }
                }

                if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        entries.isEmpty ? "Samlingen är tom" : "Inga titlar här",
                        systemImage: "rectangle.stack",
                        description: Text(entries.isEmpty
                            ? "Sök efter filmer och serier i Upptäck och spara dem här."
                            : "Välj en annan kategori eller byt filter.")
                    )
                    .foregroundStyle(.white)
                    .padding(.top, 28)
                }
            }
            .padding(.vertical, 18)
        }
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            "Ta bort från samlingen?",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { if !$0 { entryPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Ta bort", role: .destructive) {
                if let entryPendingDeletion {
                    modelContext.delete(entryPendingDeletion)
                }
                entryPendingDeletion = nil
            }
            Button("Avbryt", role: .cancel) {
                entryPendingDeletion = nil
            }
        } message: {
            Text(entryPendingDeletion?.title ?? "Titeln")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("DIN TITTARVÄRLD")
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(BingeTheme.accent)
            HStack(alignment: .firstTextBaseline) {
                Text("Min samling")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Spacer()
                Text("\(entries.count) TITLAR")
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(BingeTheme.secondaryText)
            }
        }
        .padding(.horizontal, BingeTheme.screenPadding)
    }

    private var statusOverview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                overviewCard(.watching, subtitle: "Pågår")
                overviewCard(.planned, subtitle: "På tur")
                overviewCard(.completed, subtitle: "Avklarat")
            }
            .padding(.horizontal, BingeTheme.screenPadding)
        }
    }

    private func overviewCard(_ status: BingeWatchStatus, subtitle: String) -> some View {
        let count = entries.filter {
            $0.status == status && (selectedKind == nil || $0.mediaKind == selectedKind)
        }.count
        return Button {
            withAnimation(.snappy(duration: 0.25)) {
                selectedStatus = selectedStatus == status ? nil : status
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: status.symbol)
                        .font(.headline)
                        .foregroundStyle(statusColor(status))
                    Spacer()
                    Circle()
                        .fill(statusColor(status))
                        .frame(width: 7, height: 7)
                }
                Text("\(count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BingeTheme.secondaryText)
            }
            .frame(width: 112, alignment: .leading)
            .padding(14)
            .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 17))
            .overlay {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(selectedStatus == status ? statusColor(status).opacity(0.8) : BingeTheme.separator, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func kindChip(_ title: String, kind: BingeMediaKind?) -> some View {
        let selected = selectedKind == kind
        return Button {
            withAnimation(.snappy(duration: 0.2)) { selectedKind = kind }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? .black : BingeTheme.secondaryText)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(selected ? BingeTheme.accent : BingeTheme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func statusSection(_ status: BingeWatchStatus, items: [BingeEntry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(statusColor(status))
                    .frame(width: 4, height: 20)
                Text(status.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("\(items.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(statusColor(status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(status).opacity(0.13), in: Capsule())
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selectedStatus = selectedStatus == status ? nil : status
                    }
                } label: {
                    Text(selectedStatus == status ? "Visa alla" : "Visa")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BingeTheme.secondaryText)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(items) { entry in
                        posterCard(entry)
                    }
                }
                .padding(.horizontal, BingeTheme.screenPadding)
            }
            .contentMargins(.horizontal, -BingeTheme.screenPadding)
        }
    }

    private func posterCard(_ entry: BingeEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                NavigationLink {
                    MediaDetailView(
                        id: entry.tmdbID,
                        mediaKind: entry.mediaKind,
                        fallbackTitle: entry.title,
                        fallbackOverview: entry.overview,
                        fallbackPosterPath: entry.posterPath,
                        fallbackBackdropPath: entry.backdropPath
                    )
                } label: {
                    AsyncImage(url: entry.posterURL) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            ZStack {
                                BingeTheme.elevated
                                Image(systemName: entry.mediaKind == .movie ? "film" : "tv")
                                    .font(.title)
                                    .foregroundStyle(BingeTheme.secondaryText)
                            }
                        }
                    }
                    .frame(width: 118, height: 174)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Menu {
                    ForEach(BingeWatchStatus.allCases) { status in
                        Button {
                            updateStatus(entry, to: status)
                        } label: {
                            Label(status.title, systemImage: status.symbol)
                        }
                    }
                    Divider()
                    Button("Ta bort", role: .destructive) {
                        entryPendingDeletion = entry
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.72), in: Circle())
                }
                .padding(7)
            }

            NavigationLink {
                MediaDetailView(
                    id: entry.tmdbID,
                    mediaKind: entry.mediaKind,
                    fallbackTitle: entry.title,
                    fallbackOverview: entry.overview,
                    fallbackPosterPath: entry.posterPath,
                    fallbackBackdropPath: entry.backdropPath
                )
            } label: {
                Text(entry.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(width: 118, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack(spacing: 4) {
                Image(systemName: entry.status.symbol)
                Text(entry.status.title)
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(statusColor(entry.status))
            .lineLimit(1)
        }
        .frame(width: 118, alignment: .leading)
    }

    private func updateStatus(_ entry: BingeEntry, to status: BingeWatchStatus) {
        let previousStatus = entry.status
        guard previousStatus != status else { return }
        modelContext.insert(BingeWatchEvent(
            type: .statusChanged,
            tmdbID: entry.tmdbID,
            mediaKind: entry.mediaKind,
            title: entry.title,
            detail: "\(previousStatus.title) → \(status.title)"
        ))
        entry.status = status
        switch status {
        case .watching:
            if entry.startedAt == nil { entry.startedAt = .now }
            entry.completedAt = nil
        case .completed:
            entry.completedAt = .now
            if entry.startedAt == nil { entry.startedAt = entry.addedAt }
        case .planned, .onHold, .dropped:
            entry.completedAt = nil
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
}
