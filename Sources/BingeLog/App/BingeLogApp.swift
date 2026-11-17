import SwiftUI
import SwiftData

@main
struct BingeLogApp: App {
    var body: some Scene {
        WindowGroup {
            AppShellView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [BingeEntry.self, BingeEpisodeProgress.self])
    }
}
