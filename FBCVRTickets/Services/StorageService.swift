import Foundation
import Supabase
import UniformTypeIdentifiers

enum StorageService {
    private static var db: SupabaseClient { TenantManager.shared.supabase }

    private static var mediaBucket: String {
        TenantManager.shared.config?.mediaBucket ?? "ticket-media"
    }

    static func uploadMedia(
        data: Data,
        ticketId: UUID,
        messageId: UUID,
        fileExtension: String,
        contentType: String
    ) async throws -> String {
        let path = "\(ticketId.uuidString)/\(messageId.uuidString)/\(UUID().uuidString).\(fileExtension)"
        try await db.storage
            .from(mediaBucket)
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: contentType)
            )
        return path
    }

    static func publicURL(for path: String) -> URL? {
        try? db.storage
            .from(mediaBucket)
            .getPublicURL(path: path)
    }

    static func attachmentType(for contentType: UTType) -> AttachmentType? {
        if contentType.conforms(to: .image) { return .image }
        if contentType.conforms(to: .movie) || contentType.conforms(to: .video) { return .video }
        return nil
    }

    static func fileExtension(for contentType: UTType) -> String {
        if let ext = contentType.preferredFilenameExtension { return ext }
        if contentType.conforms(to: .image) { return "jpg" }
        if contentType.conforms(to: .movie) { return "mp4" }
        return "bin"
    }
}
