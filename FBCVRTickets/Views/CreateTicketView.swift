import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PendingAttachment: Identifiable {
    let id = UUID()
    let data: Data
    let contentType: UTType
    var type: AttachmentType? { StorageService.attachmentType(for: contentType) }
}

struct CreateTicketView: View {
    @Environment(AppStateManager.self) private var stateManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var priority: TicketPriority = .medium
    @State private var departmentSlug = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var pendingAttachments: [PendingAttachment] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Ticket Details") {
                    TextField("Title", text: $title)
                    DepartmentPicker(
                        departmentSlug: $departmentSlug,
                        departments: stateManager.departments
                    )
                    Picker("Priority", selection: $priority) {
                        ForEach(TicketPriority.allCases) { p in
                            Text(p.label).tag(p)
                        }
                    }
                    TextField("Describe the issue...", text: $description, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("Attachments (optional)") {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 5,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Label("Add Photos or Videos", systemImage: "photo.on.rectangle.angled")
                    }

                    if !pendingAttachments.isEmpty {
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(pendingAttachments) { attachment in
                                    attachmentPreview(attachment)
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") { submitTicket() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
            .onAppear {
                if departmentSlug.isEmpty {
                    departmentSlug = stateManager.defaultDepartmentSlug
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                loadAttachments(from: newItems)
            }
            .overlay { if isSubmitting { LoadingOverlay() } }
        }
    }

    @ViewBuilder
    private func attachmentPreview(_ attachment: PendingAttachment) -> some View {
        if attachment.type == .image, let uiImage = UIImage(data: attachment.data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                Image(systemName: "video.fill")
                    .foregroundStyle(.white)
            }
        }
    }

    private func loadAttachments(from items: [PhotosPickerItem]) {
        Task {
            var loaded: [PendingAttachment] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let contentType: UTType
                if let type = item.supportedContentTypes.first {
                    contentType = type
                } else {
                    contentType = .jpeg
                }
                if StorageService.attachmentType(for: contentType) != nil {
                    loaded.append(PendingAttachment(data: data, contentType: contentType))
                }
            }
            await MainActor.run { pendingAttachments = loaded }
        }
    }

    private func submitTicket() {
        guard let userId = stateManager.currentUserId,
              let email = stateManager.currentUserEmail else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                let ticket = try await TicketService.createTicket(NewTicket(
                    user_id: userId,
                    user_email: email,
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description.trimmingCharacters(in: .whitespaces),
                    priority: priority,
                    department: departmentSlug
                ))

                let messageBody = description.trimmingCharacters(in: .whitespaces)
                let messageId = UUID()
                try await TicketService.sendMessage(NewMessage(
                    id: messageId,
                    ticket_id: ticket.id,
                    user_id: userId,
                    user_email: email,
                    is_admin: stateManager.isAdmin,
                    body: messageBody.isEmpty ? "Ticket created." : messageBody
                ))

                for attachment in pendingAttachments {
                        guard let type = attachment.type else { continue }
                        let ext = StorageService.fileExtension(for: attachment.contentType)
                        let mime = attachment.contentType.preferredMIMEType ?? "application/octet-stream"
                        let path = try await StorageService.uploadMedia(
                            data: attachment.data,
                            ticketId: ticket.id,
                            messageId: messageId,
                            fileExtension: ext,
                            contentType: mime
                        )
                        _ = try await TicketService.saveAttachment(NewAttachment(
                            message_id: messageId,
                            ticket_id: ticket.id,
                            file_path: path,
                            file_type: type
                        ))
                }

                await MainActor.run {
                    stateManager.refreshAllTicketData()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create ticket. Please try again."
                    isSubmitting = false
                }
                print("Create ticket error: \(error)")
            }
        }
    }
}
