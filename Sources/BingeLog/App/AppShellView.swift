import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Hem"
    case collection = "Samling"
    case discover = "Upptäck"
    case calendar = "Kalender"
    case profile = "Profil"

    var id: String { rawValue }

    var symbol: String {
        return switch self {
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
                .tabItem {
                    Label(tab.rawValue, systemImage: tab.symbol)
                }
                .tag(tab)
            }
        }
        .tint(BingeTheme.accent)
        .background(BingeTheme.background)
    }

    @ViewBuilder
    private func destination(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .collection:
            PlaceholderSectionView(title: "Min samling", subtitle: "Dina filmer, serier och personliga listor samlade på ett ställe.", symbol: "rectangle.stack")
        case .discover:
            DiscoverView()
        case .calendar:
            PlaceholderSectionView(title: "Kalender", subtitle: "Premiärer, nya avsnitt och kommande släpp.", symbol: "calendar")
        case .profile:
            PlaceholderSectionView(title: "Din profil", subtitle: "Tittarstatistik, inställningar och anslutna tjänster.", symbol: "person.crop.circle")
        }
    }
}

private struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                VStack(alignment: .leading, spacing: 8) {
                    Text("DIN NÄSTA KVÄLL")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(BingeTheme.accent)
                    Text("Hitta något\nvärt att titta på.")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .tracking(-1.2)
                        .foregroundStyle(BingeTheme.primaryText)
                    Text("Din film- och serievärld börjar här.")
                        .font(.subheadline)
                        .foregroundStyle(BingeTheme.secondaryText)
                }
                HomeSectionCard(title: "Fortsätt titta", subtitle: "Koppla TMDB eller Jellyfin för att komma igång.", symbol: "play.rectangle")
                HomeSectionCard(title: "Kommande premiärer", subtitle: "Nya filmer och avsnitt att hålla koll på.", symbol: "calendar.badge.clock")
                HomeSectionCard(title: "Din samling", subtitle: "Bygg din egen tittarhistorik och dina listor.", symbol: "books.vertical")
            }
            .padding(BingeTheme.screenPadding)
        }
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
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
            Image(systemName: "bell")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(BingeTheme.surface, in: Circle())
                .accessibilityLabel("Notiser")
        }
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
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(BingeTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BingeTheme.secondaryText)
        }
        .padding(16)
        .background(BingeTheme.surface, in: RoundedRectangle(cornerRadius: BingeTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BingeTheme.cardRadius)
                .stroke(BingeTheme.separator, lineWidth: 1)
        }
    }
}

private struct PlaceholderSectionView: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(BingeTheme.accent)
            Text(title).font(.largeTitle.bold()).foregroundStyle(.white)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(BingeTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BingeTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}
