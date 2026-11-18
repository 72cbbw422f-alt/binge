import SwiftData
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Hem"
    case collection = "Samling"
    case discover = "Upptäck"
    case calendar = "Kalender"
    case profile = "Profil"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "house"
        case .collection: "rectangle.stack"
        case .discover: "safari"
        case .calendar: "calendar"
        case .profile: "person.crop.circle"
        }
    }
}

struct AppShellView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    destination(for: tab)
                }
                .tabItem { Label(tab.rawValue, systemImage: tab.symbol) }
                .tag(tab)
            }
        }
        .tint(BingeTheme.accent)
        .background(BingeTheme.background)
    }

    @ViewBuilder
    private func destination(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .collection: CollectionView()
        case .discover: DiscoverView()
        case .calendar: CalendarView()
        case .profile: ProfileView()
        }
    }
}

private struct HomeView: View {
    @Query private var entries: [BingeEntry]
    @Query(sort: \BingeWatchEvent.occurredAt, order: .reverse) private var events: [BingeWatchEvent]

    private var watchingCount: Int { entries.filter { $0.status == .watching }.count }
    private var plannedCount: Int { entries.filter { $0.status == .planned }.count }
    private var completedCount: Int { entries.filter { $0.status == .completed }.count }
    private var completedMoviesCount: Int { entries.filter { $0.status == .completed && $0.mediaKind == .movie }.count }
    private var completedSeriesCount: Int { entries.filter { $0.status == .completed && $0.mediaKind == .tv }.count }
    private var ratedEntries: [BingeEntry] { entries.filter { $0.userRating != nil } }
    private var averagePersonalRating: Double? {
        guard !ratedEntries.isEmpty else { return nil }
        return ratedEntries.compactMap(\.userRating).reduce(0, +) / Double(ratedEntries.count)
    }
    private var currentMonthEvents: [BingeWatchEvent] {
        events.filter { Calendar.current.isDate($0.occurredAt, equalTo: .now, toGranularity: .month) }
    }
    private var activeDaysThisMonth: Int {
        Set(currentMonthEvents.map { Calendar.current.startOfDay(for: $0.occurredAt) }).count
    }
    private var continueWatching: [BingeEntry] {
        entries.filter { $0.status == .watching && $0.mediaKind == .tv }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "play.square.stack.fill")
                            .font(.title2)
                            .foregroundStyle(BingeTheme.accent)
                        Text("BingeLog")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text("DIN TITTARVÄRLD")
                        .font(.caption2.weight(.bold))
                        .tracking(1)
                        .foregroundStyle(BingeTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("DIN NÄSTA KVÄLL")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(BingeTheme.accent)
                    Text("Hitta något\nvärt att titta på.")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .tracking(-1.2)
                        .foregroundStyle(BingeTheme.primaryText)
                    Text("Håll ordning på allt du ser – och allt du vill se.")
                        .font(.subheadline)
                        .foregroundStyle(BingeTheme.secondaryText)
                }

                HStack(spacing: 10) {
                    statCard(title: "Tittar på", count: watchingCount, symbol: "play.circle")
                    statCard(title: "Vill se", count: plannedCount, symbol: "bookmark")
                    statCard(title: "Sett klart", count: completedCount, symbol: "checkmark.circle")
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading("Din statistik", subtitle: "En snabb överblick över det du sett")
                    HStack(spacing: 10) {
                        insightCard(title: "Filmer", value: "\(completedMoviesCount)", detail: "Sett klart", symbol: "film")
                        insightCard(title: "Serier", value: "\(completedSeriesCount)", detail: "Sett klart", symbol: "tv")
                        insightCard(title: "Snittbetyg", value: averagePersonalRating.map { String(format: "%.1f", $0) } ?? "–", detail: "\(ratedEntries.count) betyg", symbol: "star")
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading("Din aktivitet", subtitle: "Så har du använt BingeLog den här månaden")
                    HStack(spacing: 10) {
                        insightCard(title: "Aktiviteter", value: "\(currentMonthEvents.count)", detail: "Den här månaden", symbol: "chart.bar")
                        insightCard(title: "Aktiva dagar", value: "\(activeDaysThisMonth)", detail: "Med registrerad aktivitet", symbol: "calendar")
                    }
                }

                if !continueWatching.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeading("Fortsätt titta", subtitle: "Dina pågående serier")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(continueWatching) { entry in
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
                                        VStack(alignment: .leading, spacing: 7) {
                                            AsyncImage(url: entry.posterURL) { phase in
                                                if let image = phase.image {
                                                    image.resizable().scaledToFill()
                                                } else {
                                                    ZStack {
                                                        BingeTheme.elevated
                                                        Image(systemName: "tv").foregroundStyle(BingeTheme.secondaryText)
                                                    }
                                                }
                                            }
                                            .frame(width: 112, height: 164)
                                            .clipShape(RoundedRectangle(cornerRadius: 11))
                                            Text(entry.title)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(2)
                                                .frame(width: 112, alignment: .leading)
                                            Label("Tittar på", systemImage: "play.circle.fill")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(BingeTheme.accent)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        sectionHeading("Senaste aktivitet", subtitle: "Din personliga tittarhistorik")
                        Spacer()
                        NavigationLink("Visa alla") { WatchHistoryView() }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BingeTheme.accent)
                    }
                    if events.isEmpty {
                        HomeSectionCard(
                            title: "Historiken börjar här",
                            subtitle: "När du ändrar status på en titel eller markerar ett avsnitt som sett visas aktiviteten här.",
                            symbol: "clock"
                        )
                    } else {
                        VStack(spacing: 0) {
                            ForEach(events.prefix(8)) { event in
                                HStack(spacing: 12) {
                                    Image(systemName: event.eventType == .episodeWatched ? "checkmark.circle.fill" : event.eventType == .episodeUnwatched ? "arrow.uturn.backward.circle" : "arrow.left.arrow.right.circle")
                                        .font(.title3)
                                        .foregroundStyle(BingeTheme.accent)
                                        .frame(width: 34, height: 34)
                                        .background(BingeTheme.accent.opacity(0.12), in: Circle())
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(event.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text(event.summary)
                                            .font(.caption)
                                            .foregroundStyle(BingeTheme.secondaryText)
                                            .lineLimit(2)
                                    }
                                    Spacer(minLength: 4)
                                    Text(event.occurredAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(BingeTheme.secondaryText)
                                }
                                .padding(.vertical, 11)
                                if event.id != events.prefix(8).last?.id {
                                    Divider().overlay(BingeTheme.separator)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                }

                if entries.isEmpty {
                    HomeSectionCard(title: "Fortsätt bygga samlingen", subtitle: "Sök efter filmer och serier i Upptäck och spara dem här.", symbol: "rectangle.stack")
                }
            }
            .padding(BingeTheme.screenPadding)
        }
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.bold()).foregroundStyle(.white)
            Text(subtitle).font(.caption).foregroundStyle(BingeTheme.secondaryText)
        }
    }

    private func insightCard(title: String, value: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).font(.subheadline).foregroundStyle(BingeTheme.accent)
            Text(value).font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white)
            Text(detail).font(.caption2).foregroundStyle(BingeTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 15))
    }

    private func statCard(title: String, count: Int, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.subheadline).foregroundStyle(BingeTheme.accent)
            Text("\(count)").font(.system(size: 25, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(title).font(.caption2).foregroundStyle(BingeTheme.secondaryText).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct WatchHistoryView: View {
    @Query(sort: \BingeWatchEvent.occurredAt, order: .reverse) private var events: [BingeWatchEvent]
    @State private var selectedFilter = "all"

    private var filteredEvents: [BingeWatchEvent] {
        switch selectedFilter {
        case "episodes": events.filter { $0.eventType == .episodeWatched || $0.eventType == .episodeUnwatched }
        case "status": events.filter { $0.eventType == .statusChanged }
        default: events
        }
    }

    private var groupedEvents: [(date: Date, events: [BingeWatchEvent])] {
        let groups = Dictionary(grouping: filteredEvents) { Calendar.current.startOfDay(for: $0.occurredAt) }
        return groups.keys.sorted(by: >).map { date in
            (date: date, events: groups[date, default: []])
        }
    }

    private func sectionTitle(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Idag" }
        if Calendar.current.isDateInYesterday(date) { return "Igår" }
        return date.formatted(date: .complete, time: .omitted)
    }

    var body: some View {
        List {
            Section {
                Picker("Visa aktivitet", selection: $selectedFilter) {
                    Text("Allt").tag("all")
                    Text("Avsnitt").tag("episodes")
                    Text("Status").tag("status")
                }
                .pickerStyle(.segmented)
                .listRowBackground(BingeTheme.background)
            }

            ForEach(groupedEvents, id: \.date) { group in
                Section {
                    ForEach(group.events) { event in
                        HStack(spacing: 12) {
                            Image(systemName: event.eventType == .episodeWatched ? "checkmark.circle.fill" : event.eventType == .episodeUnwatched ? "arrow.uturn.backward.circle" : "arrow.left.arrow.right.circle")
                                .foregroundStyle(BingeTheme.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                Text(event.summary).font(.caption).foregroundStyle(BingeTheme.secondaryText)
                                Text(event.occurredAt.formatted(date: .omitted, time: .shortened)).font(.caption2).foregroundStyle(BingeTheme.secondaryText)
                            }
                        }
                        .listRowBackground(BingeTheme.surface)
                    }
                } header: {
                    Text(sectionTitle(for: group.date))
                        .foregroundStyle(BingeTheme.accent)
                }
            }

            if filteredEvents.isEmpty {
                Text(events.isEmpty
                    ? "Din tittarhistorik visas här när du börjar använda BingeLog."
                    : "Det finns ingen aktivitet av den här typen ännu.")
                    .foregroundStyle(BingeTheme.secondaryText)
                    .listRowBackground(BingeTheme.surface)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(BingeTheme.background)
        .navigationTitle("Aktivitet")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HomeSectionCard: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(BingeTheme.accent)
                .frame(width: 48, height: 48)
                .background(BingeTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.subheadline).foregroundStyle(BingeTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: BingeTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BingeTheme.cardRadius).stroke(BingeTheme.separator, lineWidth: 1)
        }
    }
}

private struct PlaceholderSectionView: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.system(size: 42, weight: .light)).foregroundStyle(BingeTheme.accent)
            Text(title).font(.largeTitle.bold()).foregroundStyle(.white)
            Text(subtitle).font(.body).foregroundStyle(BingeTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}


private struct ProfileView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("INSTÄLLNINGAR")
                        .font(.caption.weight(.bold)).tracking(1.4)
                        .foregroundStyle(BingeTheme.accent)
                    Text("Din profil")
                        .font(.largeTitle.bold()).foregroundStyle(.white)
                    Text("Hantera anslutningar och importera din befintliga tittarhistorik.")
                        .font(.subheadline).foregroundStyle(BingeTheme.secondaryText)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("ANSLUTNINGAR")
                        .font(.caption.weight(.bold))
                        .tracking(1.3)
                        .foregroundStyle(BingeTheme.secondaryText)
                    connectionRow(
                        title: "TMDB",
                        subtitle: "Filmer, serier och premiärinformation",
                        connected: SecureTokenStore.read(service: "BingeLog.TMDB") != nil,
                        symbol: "film.stack"
                    )
                    connectionRow(
                        title: "MDBList",
                        subtitle: "Import av dina personliga listor",
                        connected: SecureTokenStore.read(service: "BingeLog.MDBList") != nil,
                        symbol: "list.bullet.rectangle"
                    )
                    Text("Statusen visar om en nyckel finns sparad – inte om tjänsten har verifierat den. TMDB hanteras under Upptäck och MDBList via importfunktionen nedan.")
                        .font(.caption2)
                        .foregroundStyle(BingeTheme.secondaryText)
                }
                .padding(15)
                .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                NavigationLink {
                    MDBListImportView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title2).foregroundStyle(BingeTheme.accent)
                            .frame(width: 46, height: 46)
                            .background(BingeTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Importera från MDBList").font(.headline).foregroundStyle(.white)
                            Text("Hämta dina egna filmer och serielistor").font(.caption).foregroundStyle(BingeTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(BingeTheme.secondaryText)
                    }
                    .padding(15)
                    .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            .padding(BingeTheme.screenPadding)
        }
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func connectionRow(title: String, subtitle: String, connected: Bool, symbol: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(BingeTheme.accent)
                .frame(width: 38, height: 38)
                .background(BingeTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(BingeTheme.secondaryText)
            }
            Spacer()
            Label(connected ? "Nyckel sparad" : "Ej konfigurerad", systemImage: connected ? "checkmark.circle.fill" : "minus.circle")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(connected ? BingeTheme.accent : BingeTheme.secondaryText)
        }
    }
}
