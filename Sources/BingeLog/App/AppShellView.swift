import SwiftData
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Hem"
    case collection = "Samling"
    case discover = "Upptäck"
    case calendar = "Kalender"
    case importer = "Importera"
    case profile = "Profil"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: "house"
        case .collection: "rectangle.stack"
        case .discover: "safari"
        case .calendar: "calendar"
        case .importer: "square.and.arrow.down"
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
        case .calendar:
            PlaceholderSectionView(title: "Kalender", subtitle: "Premiärer, nya avsnitt och kommande släpp.", symbol: "calendar")
        case .importer: MDBListImportView()
        case .profile:
            PlaceholderSectionView(title: "Din profil", subtitle: "Tittarstatistik, inställningar och anslutna tjänster.", symbol: "person.crop.circle")
        }
    }
}

private struct HomeView: View {
    @Query private var entries: [BingeEntry]

    private var watchingCount: Int { entries.filter { $0.status == .watching }.count }
    private var plannedCount: Int { entries.filter { $0.status == .planned }.count }

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

                HomeSectionCard(title: "Fortsätt bygga samlingen", subtitle: "Sök efter filmer och serier i Upptäck och spara dem här.", symbol: "rectangle.stack")
            }
            .padding(BingeTheme.screenPadding)
        }
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
