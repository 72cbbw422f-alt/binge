import SwiftData
import SwiftUI

struct CollectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BingeEntry.addedAt, order: .reverse) private var entries: [BingeEntry]
    @State private var selectedStatus: BingeWatchStatus?
    @State private var selectedKind: BingeMediaKind?

    private var filteredEntries: [BingeEntry] {
        entries.filter { entry in
            (selectedStatus == nil || entry.status == selectedStatus) &&
            (selectedKind == nil || entry.mediaKind == selectedKind)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("DIN BIBLIOTEK")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(BingeTheme.accent)
                    Text("Min samling")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("\(entries.count) titlar sparade")
                        .font(.subheadline)
                        .foregroundStyle(BingeTheme.secondaryText)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip("Allt", isSelected: selectedStatus == nil) { selectedStatus = nil }
                        ForEach(BingeWatchStatus.allCases) { status in
                            filterChip(status.title, isSelected: selectedStatus == status) {
                                selectedStatus = selectedStatus == status ? nil : status
                            }
                        }
                    }
                    .padding(.horizontal, BingeTheme.screenPadding)
                }
                .contentMargins(.horizontal, -BingeTheme.screenPadding)

                HStack(spacing: 8) {
                    filterChip("Alla", isSelected: selectedKind == nil) { selectedKind = nil }
                    filterChip("Filmer", isSelected: selectedKind == .movie) {
                        selectedKind = selectedKind == .movie ? nil : .movie
                    }
                    filterChip("Serier", isSelected: selectedKind == .tv) {
                        selectedKind = selectedKind == .tv ? nil : .tv
                    }
                }

                if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        entries.isEmpty ? "Samlingen är tom" : "Inga träffar",
                        systemImage: "rectangle.stack",
                        description: Text(entries.isEmpty
                            ? "Spara filmer och serier från Upptäck så hamnar de här."
                            : "Prova att ändra filtren.")
                    )
                    .foregroundStyle(.white)
                    .padding(.top, 36)
                } else {
                    LazyVStack(spacing: 11) {
                        ForEach(filteredEntries) { entry in
                            entryRow(entry)
                        }
                    }
                }
            }
            .padding(BingeTheme.screenPadding)
        }
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func filterChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .black : BingeTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isSelected ? BingeTheme.accent : BingeTheme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func entryRow(_ entry: BingeEntry) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: entry.posterURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    ZStack {
                        BingeTheme.elevated
                        Image(systemName: "film").foregroundStyle(BingeTheme.secondaryText)
                    }
                }
            }
            .frame(width: 62, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 7) {
                    Text(entry.mediaKind.title.uppercased())
                    if let year = entry.year { Text("· \(year)") }
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(BingeTheme.accent)
                Menu {
                    ForEach(BingeWatchStatus.allCases) { status in
                        Button {
                            updateStatus(entry, to: status)
                        } label: {
                            Label(status.title, systemImage: status.symbol)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: entry.status.symbol)
                            .font(.caption.weight(.bold))
                        Text(entry.status.title)
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(statusColor(entry.status))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor(entry.status).opacity(0.16), in: Capsule())
                    .overlay(Capsule().stroke(statusColor(entry.status).opacity(0.42), lineWidth: 1))
                }
                .buttonStyle(.plain)
                if let rating = entry.userRating {
                    Label(rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(BingeTheme.secondaryText)
                }
            }
            Spacer(minLength: 0)
            Menu {
                Button("Ta bort ur samlingen", role: .destructive) {
                    modelContext.delete(entry)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(BingeTheme.secondaryText)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
        }
        .padding(10)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 14))
    }
    private func updateStatus(_ entry: BingeEntry, to status: BingeWatchStatus) {
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
