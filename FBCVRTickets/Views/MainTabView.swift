import SwiftUI

struct MainTabView: View {
    @Environment(AppStateManager.self) private var stateManager

    var body: some View {
        if stateManager.isAdmin {
            TabView {
                NavigationStack {
                    TicketListContentView()
                }
                .tabItem {
                    Label("Tickets", systemImage: "ticket")
                }

                NavigationStack {
                    ArchiveTicketListView()
                }
                .tabItem {
                    Label("Archive", systemImage: "archivebox")
                }

                NavigationStack {
                    AdminAnalyticsView()
                }
                .tabItem {
                    Label("Analytics", systemImage: "chart.bar")
                }
            }
            .tint(.white)
            .onAppear { AdminTabBarStyle.apply() }
        } else {
            NavigationStack {
                TicketListContentView()
            }
        }
    }
}
