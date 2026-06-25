import Foundation
import Supabase
import UIKit
import UserNotifications

@MainActor
final class PushNotificationService {
    static let shared = PushNotificationService()

    private let tokenStorageKey = "supasupport.push.deviceToken"

    private init() {}

    private var db: SupabaseClient { TenantManager.shared.supabase }

    func registerAfterSignIn() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else {
                print("Push notifications not authorized by user")
                return
            }
            UIApplication.shared.registerForRemoteNotifications()
        } catch {
            print("Push authorization error: \(error.localizedDescription)")
        }
    }

    func saveDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenStorageKey)

        do {
            let userId = try await db.auth.session.user.id
            try await upsertToken(userId: userId, token: token)
        } catch {
            print("Failed to save push token: \(error.localizedDescription)")
        }
    }

    func removeStoredDeviceToken() async {
        guard let token = UserDefaults.standard.string(forKey: tokenStorageKey) else { return }

        do {
            let userId = try await db.auth.session.user.id
            try await db
                .from("push_device_tokens")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("device_token", value: token)
                .execute()
        } catch {
            print("Failed to remove push token: \(error.localizedDescription)")
        }

        UserDefaults.standard.removeObject(forKey: tokenStorageKey)
    }

    private func upsertToken(userId: UUID, token: String) async throws {
        struct TokenRow: Encodable {
            let user_id: UUID
            let device_token: String
            let platform: String
        }

        try await db
            .from("push_device_tokens")
            .upsert(
                TokenRow(user_id: userId, device_token: token, platform: "ios"),
                onConflict: "user_id,device_token"
            )
            .execute()
    }
}
