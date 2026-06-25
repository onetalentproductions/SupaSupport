import Foundation
import Supabase

struct Department: Codable, Identifiable, Hashable {
    let slug: String
    let label: String
    let sort_order: Int
    let color_hex: String?

    var id: String { slug }
}

struct OrgMembership: Codable {
    let role: String?
    let department_slugs: [String]
    let email: String?

    var isAdmin: Bool { role == "admin" }
}

struct DepartmentCompletion: Codable, Identifiable {
    let slug: String
    let label: String
    let completed_count: Int

    var id: String { slug }
}

enum OrgService {
    private static var db: SupabaseClient { TenantManager.shared.supabase }

    static func fetchDepartments() async throws -> [Department] {
        try await db
            .from("departments")
            .select()
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    static func fetchOrgName() async throws -> String {
        struct Row: Decodable { let org_name: String }
        let rows: [Row] = try await db.from("org_settings").select("org_name").limit(1).execute().value
        return rows.first?.org_name ?? TenantManager.shared.config?.orgName ?? "Organization"
    }

    static func fetchMembership() async throws -> OrgMembership {
        let row: MembershipRow = try await db.rpc("get_my_membership").execute().value
        return OrgMembership(role: row.role, department_slugs: row.department_slugs ?? [], email: row.email)
    }

    static func redeemInviteIfNeeded() async throws -> OrgMembership {
        if let token = TenantManager.shared.pendingInviteToken {
            TenantManager.shared.pendingInviteToken = nil
            let _: MembershipRow = try await db.rpc("redeem_invite", params: ["p_token": token]).execute().value
            return try await fetchMembership()
        }

        let membership = try await fetchMembership()
        if membership.role != nil {
            return membership
        }

        let _: MembershipRow = try await db.rpc("claim_pending_membership").execute().value
        return try await fetchMembership()
    }

    static func createInvite(role: String, departmentSlugs: [String], email: String?) async throws -> String {
        struct Params: Encodable {
            let p_role: String
            let p_department_slugs: [String]
            let p_email: String?
        }
        let row: InviteRow = try await db.rpc(
            "create_invite",
            params: Params(p_role: role, p_department_slugs: departmentSlugs, p_email: email?.nilIfEmpty)
        ).execute().value
        guard let token = row.token else { throw OrgServiceError.missingToken }
        return token
    }

    static func addPendingMember(email: String, role: String, departmentSlugs: [String]) async throws {
        struct Params: Encodable {
            let p_email: String
            let p_role: String
            let p_department_slugs: [String]
        }
        let _: OkRow = try await db.rpc(
            "add_pending_member",
            params: Params(p_email: email, p_role: role, p_department_slugs: departmentSlugs)
        ).execute().value
    }

    static func buildInvitePayload(token: String) -> String {
        guard let config = TenantManager.shared.config else { return token }
        return ConnectPayloadParser.encodeJSON(
            orgName: config.orgName,
            url: config.supabaseURL,
            key: config.supabaseAnonKey,
            invite: token
        )
    }

    static func fetchDepartmentCompletionCounts() async throws -> [DepartmentCompletion] {
        try await db.rpc("get_department_completion_counts").execute().value
    }
}

private struct MembershipRow: Decodable {
    let role: String?
    let department_slugs: [String]?
    let email: String?
}

private struct InviteRow: Decodable {
    let token: String?
}

private struct OkRow: Decodable {
    let ok: Bool?
}

enum OrgServiceError: LocalizedError {
    case missingToken
    case notAMember

    var errorDescription: String? {
        switch self {
        case .missingToken: "Could not create invite."
        case .notAMember: "You are not a member of this organization. Ask your admin for an invite."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
