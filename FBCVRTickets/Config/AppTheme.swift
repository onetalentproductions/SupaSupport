import SwiftUI

enum AppTheme {
    /// Primary brand green (dark green accent).
    static let accent = Color(red: 0.12, green: 0.52, blue: 0.28)
    static let accentLight = Color(red: 0.18, green: 0.62, blue: 0.34)
    static let accentDark = Color(red: 0.06, green: 0.28, blue: 0.14)

    static let chromeBlack = Color.black
    static let surfaceDark = Color(red: 0.08, green: 0.10, blue: 0.08)

    static var startupGradient: LinearGradient {
        LinearGradient(
            colors: [Color.black, accentDark, Color(white: 0.06)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var actionBarGradient: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.10), accentDark, accent.opacity(0.85)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var cardTintGradient: LinearGradient {
        LinearGradient(
            colors: [
                accent.opacity(0.10),
                Color.clear,
                accentDark.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentUIColor: UIColor {
        UIColor(red: 0.12, green: 0.52, blue: 0.28, alpha: 1)
    }
}
