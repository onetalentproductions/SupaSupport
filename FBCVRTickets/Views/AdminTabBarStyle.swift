import SwiftUI

enum AdminTabBarStyle {
    static func apply() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black

        let normal = appearance.stackedLayoutAppearance.normal
        normal.iconColor = UIColor(white: 0.35, alpha: 1)
        normal.titleTextAttributes = [.foregroundColor: UIColor(white: 0.35, alpha: 1)]

        let selected = appearance.stackedLayoutAppearance.selected
        selected.iconColor = .white
        selected.titleTextAttributes = [.foregroundColor: UIColor.white]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
