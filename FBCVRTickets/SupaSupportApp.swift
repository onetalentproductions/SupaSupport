//
//  SupaSupportApp.swift
//  SupaSupport
//

import SwiftUI
import GoogleSignIn

@main
struct SupaSupportApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        GoogleAuth.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url.scheme == "supasupport" {
                        Task { @MainActor in
                            await handleConnectURL(url)
                        }
                    } else {
                        GIDSignIn.sharedInstance.handle(url)
                    }
                }
        }
    }

    @MainActor
    private func handleConnectURL(_ url: URL) async {
        do {
            let (config, invite) = try ConnectPayloadParser.parseDeepLink(url)
            TenantManager.shared.connect(config: config, inviteToken: invite)
        } catch {
            print("Connect URL error: \(error.localizedDescription)")
        }
    }
}
