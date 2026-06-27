import SwiftUI

struct ContentView: View {
    @State private var stateManager = AppStateManager()

    var body: some View {
        ZStack {
            AppStartup()

            VStack(spacing: 0) {
                AppTopChrome()
                    .environment(stateManager)

                Group {
                    if stateManager.isLoggedIn {
                        MainTabView()
                            .environment(stateManager)
                    } else {
                        ConnectView()
                            .environment(stateManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: Binding(
            get: { stateManager.showInviteUserSheet },
            set: { stateManager.showInviteUserSheet = $0 }
        )) {
            InviteUserView()
                .environment(stateManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: .tenantConnectionChanged)) { _ in
            stateManager.isConnected = TenantManager.shared.isConnected
            stateManager.orgName = TenantManager.shared.config?.orgName ?? AppConfig.appName
        }
    }
}

#Preview {
    ContentView()
}
