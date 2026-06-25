import Foundation
import Supabase

enum TicketService {
    private static var db: SupabaseClient { TenantManager.shared.supabase }

    static func fetchActiveTickets(
        forUserId userId: UUID?,
        isAdmin: Bool,
        adminDepartmentSlugs: [String]
    ) async throws -> [Ticket] {
        var query = db.from("tickets").select()
        if isAdmin {
            query = query.neq("status", value: TicketStatus.complete.rawValue)
            if !adminDepartmentSlugs.isEmpty {
                query = query.in("department", values: adminDepartmentSlugs)
            }
        } else if let userId {
            query = query.eq("user_id", value: userId)
        }
        return try await query
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    static func fetchArchivedTickets(departmentSlugs: [String]) async throws -> [Ticket] {
        var query = db
            .from("tickets")
            .select()
            .eq("status", value: TicketStatus.complete.rawValue)
        if !departmentSlugs.isEmpty {
            query = query.in("department", values: departmentSlugs)
        }
        return try await query
            .order("completed_at", ascending: false)
            .execute()
            .value
    }

    static func fetchTicket(id: UUID) async throws -> Ticket {
        try await db
            .from("tickets")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    static func createTicket(_ ticket: NewTicket) async throws -> Ticket {
        try await db
            .from("tickets")
            .insert(ticket)
            .select()
            .single()
            .execute()
            .value
    }

    static func updateTicketStatus(id: UUID, status: TicketStatus, closedByEmail: String?) async throws {
        let update = TicketStatusUpdate(
            status: status,
            completed_at: status == .open ? nil : Date(),
            completed_by_email: status == .complete ? closedByEmail : nil
        )
        try await db
            .from("tickets")
            .update(update)
            .eq("id", value: id)
            .execute()
    }

    static func updateTicketDepartment(id: UUID, department: String) async throws {
        try await db
            .from("tickets")
            .update(TicketDepartmentUpdate(department: department))
            .eq("id", value: id)
            .execute()
    }

    static func authUserId() async throws -> UUID {
        try await db.auth.session.user.id
    }

    static func authUserEmail() async throws -> String {
        let session = try await db.auth.session
        guard let email = resolveEmail(session: session) else {
            throw TicketServiceError.missingUserEmail
        }
        return email
    }

    static func fetchMessages(ticketId: UUID) async throws -> [TicketMessage] {
        try await db
            .from("ticket_messages")
            .select()
            .eq("ticket_id", value: ticketId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func sendMessage(_ message: NewMessage) async throws {
        try await db
            .from("ticket_messages")
            .insert(message)
            .execute()
    }

    static func fetchAttachments(ticketId: UUID) async throws -> [TicketAttachment] {
        try await db
            .from("ticket_attachments")
            .select()
            .eq("ticket_id", value: ticketId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    static func saveAttachment(_ attachment: NewAttachment) async throws -> TicketAttachment {
        try await db
            .from("ticket_attachments")
            .insert(attachment)
            .select()
            .single()
            .execute()
            .value
    }

    static func computeDashboardAnalytics(
        activeTickets: [Ticket],
        archivedTickets: [Ticket],
        adminEmail: String?,
        departmentCompletions: [DepartmentCompletion]
    ) -> DashboardAnalytics {
        let calendar = Calendar.current
        let now = Date()
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        let normalizedAdmin = adminEmail?.lowercased().trimmingCharacters(in: .whitespaces)

        let adminCompletedCount = archivedTickets.filter { ticket in
            ticket.completed_by_email?.lowercased().trimmingCharacters(in: .whitespaces) == normalizedAdmin
        }.count

        let submissionTickets = activeTickets + archivedTickets

        var monthlySubmissions: [MonthlySubmission] = []
        for offset in (0..<6).reversed() {
            guard let monthAnchor = calendar.date(byAdding: .month, value: -offset, to: now) else { continue }
            let components = calendar.dateComponents([.year, .month], from: monthAnchor)
            guard let monthStart = calendar.date(from: components),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else { continue }

            let count = submissionTickets.filter { $0.created_at >= monthStart && $0.created_at < monthEnd }.count
            let key = "\(components.year ?? 0)-\(components.month ?? 0)"
            monthlySubmissions.append(MonthlySubmission(
                id: key,
                month: monthStart,
                label: monthFormatter.string(from: monthStart),
                count: count
            ))
        }

        let submitterCounts = Dictionary(grouping: submissionTickets, by: \.user_email)
            .map { SubmitterStat(id: $0.key, email: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)

        let outOfScope = activeTickets.filter { $0.status == .outOfScope }.count
        let active = activeTickets.filter { $0.status != .outOfScope }
        let levelSlices = [
            LevelSlice(id: "low", label: "Low", count: active.filter { $0.priority == .low }.count),
            LevelSlice(id: "medium", label: "Medium", count: active.filter { $0.priority == .medium }.count),
            LevelSlice(id: "high", label: "High", count: active.filter { $0.priority == .high || $0.priority == .urgent }.count),
            LevelSlice(id: "out_of_scope", label: "Out of Scope", count: outOfScope)
        ].filter { $0.count > 0 }

        return DashboardAnalytics(
            adminCompletedCount: adminCompletedCount,
            departmentCompletions: departmentCompletions,
            monthlySubmissions: monthlySubmissions,
            topSubmitters: Array(submitterCounts),
            levelSlices: levelSlices
        )
    }
}

enum TicketServiceError: LocalizedError {
    case missingUserEmail

    var errorDescription: String? {
        switch self {
        case .missingUserEmail:
            "Could not determine your signed-in email."
        }
    }
}
