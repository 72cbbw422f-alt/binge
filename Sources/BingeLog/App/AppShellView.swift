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

                HStack(spacing: 12) {
                    statCard(title: "Tittar på", count: watchingCount, symbol: "play.circle")
                    statCard(title: "Vill se", count: plannedCount, symbol: "bookmark")
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
                    sectionHeading("Senaste aktivitet", subtitle: "Din personliga tittarhistorik")
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

    private func statCard(title: String, count: Int, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(BingeTheme.accent)
            Text("\(count)").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(title).font(.caption).foregroundStyle(BingeTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: 16))
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
                    Text("TMDB hanteras under Upptäck. MDBList hanteras via importfunktionen nedan.")
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
            Label(connected ? "Ansluten" : "Ej ansluten", systemImage: connected ? "checkmark.circle.fill" : "minus.circle")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(connected ? BingeTheme.accent : BingeTheme.secondaryText)
        }
    }
}
