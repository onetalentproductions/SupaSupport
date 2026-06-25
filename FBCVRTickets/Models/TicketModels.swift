import Foundation

enum TicketPriority: String, Codable, CaseIterable, Identifiable {
    case low, medium, high, urgent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }

    var color: String {
        switch self {
        case .low: "green"
        case .medium: "blue"
        case .high: "orange"
        case .urgent: "red"
        }
    }
}

enum TicketStatus: String, Codable, CaseIterable {
    case open, complete, outOfScope = "out_of_scope"

    var label: String {
        switch self {
        case .open: "Open"
        case .complete: "Complete"
        case .outOfScope: "Out of Scope"
        }
    }

    var isClosed: Bool {
        self == .complete || self == .outOfScope
    }
}

struct Ticket: Codable, Identifiable, Hashable {
    let id: UUID
    let user_id: UUID
    let user_email: String
    let title: String
    let description: String
    let priority: TicketPriority
    let status: TicketStatus
    let department: String
    let created_at: Date
    let updated_at: Date
    let completed_at: Date?
    let completed_by_email: String?

    var isOpen: Bool { status == .open }
}

struct TicketMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let ticket_id: UUID
    let user_id: UUID
    let user_email: String
    let is_admin: Bool
    let body: String?
    let created_at: Date
}

struct TicketAttachment: Codable, Identifiable, Hashable {
    let id: UUID
    let message_id: UUID
    let ticket_id: UUID
    let file_path: String
    let file_type: AttachmentType
    let created_at: Date
}

enum AttachmentType: String, Codable {
    case image, video
}

struct NewTicket: Encodable {
    let user_id: UUID
    let user_email: String
    let title: String
    let description: String
    let priority: TicketPriority
    let department: String
}

struct NewMessage: Encodable {
    let id: UUID
    let ticket_id: UUID
    let user_id: UUID
    let user_email: String
    let is_admin: Bool
    let body: String
}

struct NewAttachment: Encodable {
    let message_id: UUID
    let ticket_id: UUID
    let file_path: String
    let file_type: AttachmentType
}

struct TicketStatusUpdate: Encodable {
    let status: TicketStatus
    let completed_at: Date?
    let completed_by_email: String?
}

struct TicketDepartmentUpdate: Encodable {
    let department: String
}

struct DashboardAnalytics {
    let adminCompletedCount: Int
    let departmentCompletions: [DepartmentCompletion]
    let monthlySubmissions: [MonthlySubmission]
    let topSubmitters: [SubmitterStat]
    let levelSlices: [LevelSlice]
}

struct MonthlySubmission: Identifiable {
    let id: String
    let month: Date
    let label: String
    let count: Int
}

struct SubmitterStat: Identifiable {
    let id: String
    let email: String
    let count: Int
}

struct LevelSlice: Identifiable {
    let id: String
    let label: String
    let count: Int
}

enum DepartmentPalette {
    static let colors: [ColorComponents] = [
        .init(red: 0.82, green: 0.42, blue: 0.08),
        .init(red: 0.45, green: 0.22, blue: 0.78),
        .init(red: 0.12, green: 0.55, blue: 0.75),
        .init(red: 0.18, green: 0.62, blue: 0.35),
        .init(red: 0.85, green: 0.25, blue: 0.35),
    ]

    struct ColorComponents {
        let red: Double
        let green: Double
        let blue: Double
    }

    static func color(for index: Int) -> ColorComponents {
        colors[index % colors.count]
    }
}
