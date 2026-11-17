import SwiftUI

enum BingeTheme {
    static let background = Color(hex: 0x0B0E10)
    static let surface = Color(hex: 0x151A1D)
    static let elevated = Color(hex: 0x20272B)
    static let accent = Color(hex: 0xC7F43A)
    static let secondaryAccent = Color(hex: 0xFF704D)
    static let primaryText = Color.white
    static let secondaryText = Color(hex: 0xA4ADB2)
    static let separator = Color.white.opacity(0.09)

    static let screenPadding: CGFloat = 20
    static let cardRadius: CGFloat = 18
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
