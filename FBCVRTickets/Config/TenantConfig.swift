import Foundation
import Supabase

struct TenantConfig: Codable, Equatable {
    var orgName: String
    var supabaseURL: URL
    var supabaseAnonKey: String
    var mediaBucket: String

    static let storageKey = "supasupport.tenant.config"
}

struct ConnectPayload: Codable, Equatable {
    var v: Int
    var name: String
    var url: String
    var key: String
    var invite: String?
    var bucket: String?

    func toTenantConfig() throws -> TenantConfig {
        guard v == 1 else { throw ConnectPayloadError.unsupportedVersion }
        guard let url = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ConnectPayloadError.invalidURL
        }
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ConnectPayloadError.missingKey }
        return TenantConfig(
            orgName: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Organization" : name,
            supabaseURL: url,
            supabaseAnonKey: key,
            mediaBucket: bucket ?? "ticket-media"
        )
    }
}

enum ConnectPayloadError: LocalizedError {
    case unsupportedVersion
    case invalidURL
    case missingKey
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "Unsupported connection format version."
        case .invalidURL: "Connection payload has an invalid Supabase URL."
        case .missingKey: "Connection payload is missing the anon key."
        case .invalidFormat: "Could not read connection QR or link."
        }
    }
}

enum ConnectPayloadParser {
    static func parse(_ raw: String) throws -> (TenantConfig, inviteToken: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") {
            let data = Data(trimmed.utf8)
            let payload = try JSONDecoder().decode(ConnectPayload.self, from: data)
            return (try payload.toTenantConfig(), payload.invite)
        }
        if let url = URL(string: trimmed), url.scheme == "supasupport" {
            return try parseDeepLink(url)
        }
        throw ConnectPayloadError.invalidFormat
    }

    static func parseDeepLink(_ url: URL) throws -> (TenantConfig, inviteToken: String?) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ConnectPayloadError.invalidFormat
        }
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        let payload = ConnectPayload(
            v: Int(query["v"] ?? "1") ?? 1,
            name: query["name"] ?? query["org"] ?? "Organization",
            url: query["url"] ?? "",
            key: query["key"] ?? "",
            invite: query["invite"],
            bucket: query["bucket"]
        )
        return (try payload.toTenantConfig(), payload.invite)
    }

    static func encodeJSON(orgName: String, url: URL, key: String, invite: String?) -> String {
        let payload = ConnectPayload(
            v: 1,
            name: orgName,
            url: url.absoluteString,
            key: key,
            invite: invite,
            bucket: "ticket-media"
        )
        let data = (try? JSONEncoder().encode(payload)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

@MainActor
final class TenantManager {
    static let shared = TenantManager()

    private(set) var config: TenantConfig?
    private(set) var client: SupabaseClient?
    var pendingInviteToken: String?

    private init() {
        if let data = UserDefaults.standard.data(forKey: TenantConfig.storageKey),
           let saved = try? JSONDecoder().decode(TenantConfig.self, from: data) {
            apply(saved)
        }
    }

    var isConnected: Bool { config != nil && client != nil }

    var supabase: SupabaseClient {
        guard let client else {
            fatalError("Supabase client not configured — connect to an organization first.")
        }
        return client
    }

    func connect(config: TenantConfig, inviteToken: String? = nil) {
        apply(config)
        pendingInviteToken = inviteToken
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: TenantConfig.storageKey)
        }
        NotificationCenter.default.post(name: .tenantConnectionChanged, object: nil)
    }

    func disconnect() {
        config = nil
        client = nil
        pendingInviteToken = nil
        UserDefaults.standard.removeObject(forKey: TenantConfig.storageKey)
        NotificationCenter.default.post(name: .tenantConnectionChanged, object: nil)
    }

    private func apply(_ config: TenantConfig) {
        self.config = config
        self.client = SupabaseClient(supabaseURL: config.supabaseURL, supabaseKey: config.supabaseAnonKey)
    }
}

func userDisplayEmail(session: Session, preferred: String? = nil) -> String {
    if let preferred = preferred?.lowercased().trimmingCharacters(in: .whitespaces), !preferred.isEmpty {
        return preferred
    }
    if let resolved = resolveEmail(session: session) {
        return resolved
    }
    return "\(session.user.id.uuidString.lowercased())@user.local"
}

extension Notification.Name {
    static let tenantConnectionChanged = Notification.Name("tenantConnectionChanged")
}

func resolveEmail(session: Session, googleEmail: String? = nil) -> String? {
    let candidates = [
        googleEmail,
        session.user.email,
        session.user.userMetadata["email"]?.stringValue,
        session.user.identities?
            .first(where: { $0.provider == "google" || $0.provider == "apple" })?
            .identityData?["email"]?.stringValue
    ]

    for candidate in candidates {
        if let email = candidate?.lowercased().trimmingCharacters(in: .whitespaces), !email.isEmpty {
            return email
        }
    }
    return nil
}
