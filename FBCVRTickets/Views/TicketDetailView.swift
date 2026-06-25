import SwiftUI
import PhotosUI
import AVKit

struct TicketDetailView: View {
    @Environment(AppStateManager.self) private var stateManager
    @Environment(\.dismiss) private var dismiss

    let ticket: Ticket

    @State private var messages: [TicketMessage] = []
    @State private var attachments: [TicketAttachment] = []
    @State private var replyText = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var pendingAttachments: [PendingAttachment] = []
    @State private var isSending = false
    @State private var isUpdatingStatus = false
    @State private var isLoading = false
    @State private var currentTicket: Ticket
    @State private var errorMessage: String?

    init(ticket: Ticket) {
        self.ticket = ticket
        _currentTicket = State(initialValue: ticket)
    }

    private var canReply: Bool {
        currentTicket.isOpen
    }

    private var attachmentsByMessage: [UUID: [TicketAttachment]] {
        Dictionary(grouping: attachments, by: \.message_id)
    }

    private var threadMessages: [TicketMessage] {
        if !messages.isEmpty { return messages }

        guard !currentTicket.description.isEmpty else { return [] }
        return [TicketMessage(
            id: currentTicket.id,
            ticket_id: currentTicket.id,
            user_id: currentTicket.user_id,
            user_email: currentTicket.user_email,
            is_admin: false,
            body: currentTicket.description,
            created_at: currentTicket.created_at
        )]
    }

    var body: some View {
        VStack(spacing: 0) {
            ticketHeader

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if threadMessages.isEmpty {
                            ContentUnavailableView(
                                "No Posts Yet",
                                systemImage: "text.bubble",
                                description: Text("Be the first to add to this thread.")
                            )
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 40)
                        } else {
                            ForEach(Array(threadMessages.enumerated()), id: \.element.id) { index, message in
                                ThreadPostView(
                                    message: message,
                                    attachments: attachmentsByMessage[message.id] ?? [],
                                    isOriginalPost: index == 0
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .frame(maxHeight: .infinity)
                .scrollUnderBarShadow()
                .refreshable { await loadConversation() }
                .onChange(of: threadMessages.count) { _, _ in
                    scrollToLatest(proxy)
                }
                .onChange(of: threadMessages.last?.id) { _, _ in
                    scrollToLatest(proxy)
                }
            }

            if stateManager.isAdmin {
                adminActionBar
            }

            if canReply {
                replyBar
            } else {
                closedBanner
            }
        }
        .navigationBarHidden(true)
        .onAppear { configureTopBar() }
        .onDisappear { clearTopBar() }
        .task { await loadConversation() }
        .onChange(of: selectedItems) { _, newItems in
            loadAttachments(from: newItems)
        }
        .overlay {
            if isSending || isUpdatingStatus || isLoading { LoadingOverlay() }
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let last = threadMessages.last else { return }
        DispatchQueue.main.async {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    private func configureTopBar() {
        stateManager.topBarShowsCreate = false
        stateManager.topBarShowsBack = true
        stateManager.topBarBackHandler = { dismiss() }
    }

    private func clearTopBar() {
        stateManager.topBarShowsBack = false
        stateManager.topBarBackHandler = nil
        stateManager.topBarShowsCreate = true
    }

    private var ticketHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(currentTicket.title)
                .font(.headline.bold())
                .foregroundStyle(.white)

            HStack(spacing: 8) {
                PriorityBadge(priority: currentTicket.priority)
                StatusBadge(status: currentTicket.status)
                DepartmentBadge(
                    slug: currentTicket.department,
                    label: stateManager.label(forDepartment: currentTicket.department),
                    colorIndex: stateManager.departments.firstIndex(where: { $0.slug == currentTicket.department }) ?? 0
                )
                if stateManager.isAdmin {
                    Text(currentTicket.user_email)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer()
                Text("\(messages.count) \(messages.count == 1 ? "post" : "posts")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .subtleDarkPanel()
        .scrollOcclusionShadow()
    }

    private var adminActionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if currentTicket.status != .complete {
                    adminButton("Mark Complete", icon: "checkmark.circle", color: .green) {
                        updateStatus(.complete)
                    }
                }
                if currentTicket.status != .open {
                    adminButton("Reopen", icon: "arrow.uturn.backward.circle", color: .blue) {
                        updateStatus(.open)
                    }
                }
                if currentTicket.status != .outOfScope {
                    adminButton("Out of Scope", icon: "xmark.circle", color: .purple) {
                        updateStatus(.outOfScope)
                    }
                }
                ForEach(otherDepartments) { dept in
                    adminButton("Move to \(dept.label)", icon: "arrow.left.arrow.right", color: .orange) {
                        updateDepartment(dept.slug)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .subtleDarkPanel(topOpacity: 0.14, bottomOpacity: 0.22)
    }

    private func adminButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
                .background(Capsule().fill(color.opacity(0.85)))
        }
        .disabled(isUpdatingStatus)
    }

    private var replyBar: some View {
        VStack(spacing: 8) {
            if !pendingAttachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(pendingAttachments) { att in
                            if att.type == .image, let img = UIImage(data: att.data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image(systemName: "video.fill")
                                    .frame(width: 50, height: 50)
                                    .background(Color.gray.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            HStack(alignment: .bottom, spacing: 8) {
                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 3,
                    matching: .any(of: [.images, .videos])
                ) {
                    Image(systemName: "paperclip")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(8)
                }

                TextField("Add to the thread...", text: $replyText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .subtleLightPanel()
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Button(action: sendReply) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? .white : .gray)
                }
                .disabled(!canSend || isSending)
            }
            .padding()
            .subtleDarkPanel(topOpacity: 0.22, bottomOpacity: 0.34)
        }
    }

    private var closedBanner: some View {
        HStack {
            Image(systemName: "lock.fill")
            Text(closedMessage)
                .font(.subheadline)
        }
        .foregroundStyle(.white.opacity(0.8))
        .padding()
        .frame(maxWidth: .infinity)
        .subtleDarkPanel(topOpacity: 0.22, bottomOpacity: 0.34)
    }

    private var closedMessage: String {
        switch currentTicket.status {
        case .complete: "This ticket is complete. An admin must reopen it to continue."
        case .outOfScope: "This ticket has been marked out of scope."
        case .open: ""
        }
    }

    private var canSend: Bool {
        !replyText.trimmingCharacters(in: .whitespaces).isEmpty || !pendingAttachments.isEmpty
    }

    private func loadConversation() async {
        await MainActor.run { isLoading = messages.isEmpty }
        defer { Task { @MainActor in isLoading = false } }

        do {
            async let fetchedMessages = TicketService.fetchMessages(ticketId: ticket.id)
            async let fetchedAttachments = TicketService.fetchAttachments(ticketId: ticket.id)
            async let fetchedTicket = TicketService.fetchTicket(id: ticket.id)

            let (msgs, atts, tkt) = try await (fetchedMessages, fetchedAttachments, fetchedTicket)
            await MainActor.run {
                messages = msgs
                attachments = atts
                currentTicket = tkt
                errorMessage = nil
            }
        } catch {
            print("Load conversation error: \(error)")
            await MainActor.run {
                errorMessage = "Could not load thread: \(error.localizedDescription)"
            }
        }
    }

    private func loadAttachments(from items: [PhotosPickerItem]) {
        Task {
            var loaded: [PendingAttachment] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let contentType = item.supportedContentTypes.first ?? .jpeg
                if StorageService.attachmentType(for: contentType) != nil {
                    loaded.append(PendingAttachment(data: data, contentType: contentType))
                }
            }
            await MainActor.run { pendingAttachments = loaded }
        }
    }

    private func sendReply() {
        isSending = true
        errorMessage = nil

        Task {
            do {
                let userId = try await TicketService.authUserId()
                let email = try await TicketService.authUserEmail()
                let body = replyText.trimmingCharacters(in: .whitespaces)
                let messageId = UUID()

                try await TicketService.sendMessage(NewMessage(
                    id: messageId,
                    ticket_id: ticket.id,
                    user_id: userId,
                    user_email: email,
                    is_admin: stateManager.isAdmin,
                    body: body
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
                    replyText = ""
                    pendingAttachments = []
                    selectedItems = []
                }

                await loadConversation()
                await MainActor.run { isSending = false }
            } catch {
                print("Send reply error: \(error)")
                await MainActor.run {
                    errorMessage = "Failed to send reply: \(error.localizedDescription)"
                    isSending = false
                }
            }
        }
    }

    private func updateStatus(_ status: TicketStatus) {
        isUpdatingStatus = true
        Task {
            do {
                try await TicketService.updateTicketStatus(
                    id: ticket.id,
                    status: status,
                    closedByEmail: status == .complete ? stateManager.currentUserEmail : nil
                )
                let updated = try await TicketService.fetchTicket(id: ticket.id)
                await MainActor.run {
                    currentTicket = updated
                    isUpdatingStatus = false
                    stateManager.refreshAllTicketData()
                    if status == .complete {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update status."
                    isUpdatingStatus = false
                }
            }
        }
    }

    private var otherDepartments: [Department] {
        stateManager.departments.filter { $0.slug != currentTicket.department }
    }

    private func updateDepartment(_ slug: String) {
        isUpdatingStatus = true
        Task {
            do {
                try await TicketService.updateTicketDepartment(id: ticket.id, department: slug)
                await MainActor.run {
                    isUpdatingStatus = false
                    stateManager.refreshAllTicketData()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to move ticket to \(stateManager.label(forDepartment: slug))."
                    isUpdatingStatus = false
                }
            }
        }
    }
}

struct ThreadPostView: View {
    let message: TicketMessage
    let attachments: [TicketAttachment]
    let isOriginalPost: Bool

    private var displayName: String {
        let email = message.user_email
        let local = email.split(separator: "@").first.map(String.init) ?? email
        return local.replacingOccurrences(of: ".", with: " ").capitalized
    }

    private var initial: String {
        String(displayName.prefix(1)).uppercased()
    }

    private var accentColor: Color {
        message.is_admin ? .orange : .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.85))
                        .frame(width: 40, height: 40)
                    Text(initial)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        if message.is_admin {
                            roleBadge("Admin", color: Color(red: 0.82, green: 0.42, blue: 0.08))
                        }
                        if isOriginalPost {
                            roleBadge("Original", color: Color(red: 0.12, green: 0.42, blue: 0.82))
                        }

                        Spacer()

                        Text(message.created_at, format: CommentTimestamp.format)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(message.user_email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            VStack(alignment: .leading, spacing: 12) {
                if let body = message.body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(body)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else if attachments.isEmpty {
                    Text("Sent an attachment")
                        .font(.body.italic())
                        .foregroundStyle(.secondary)
                }

                ForEach(attachments) { attachment in
                    AttachmentView(attachment: attachment)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .padding(.leading, 52)
        }
        .subtleCardGradient()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(accentColor)
                .frame(width: 4)
        }
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    private func roleBadge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(Capsule().fill(color))
    }
}

struct AttachmentView: View {
    let attachment: TicketAttachment

    var body: some View {
        Group {
            if attachment.file_type == .image {
                AsyncImage(url: StorageService.publicURL(for: attachment.file_path)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    default:
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if let url = StorageService.publicURL(for: attachment.file_path) {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
