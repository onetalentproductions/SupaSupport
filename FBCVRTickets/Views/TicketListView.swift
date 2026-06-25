import SwiftUI

struct TicketListContentView: View {
    @Environment(AppStateManager.self) private var stateManager
    @State private var showCompletedTickets = false

    private var displayedTickets: [Ticket] {
        guard !stateManager.isAdmin else { return stateManager.userTickets }
        guard showCompletedTickets else {
            return stateManager.userTickets.filter { $0.status != .complete }
        }
        return stateManager.userTickets
    }

    var body: some View {
        @Bindable var state = stateManager

        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if displayedTickets.isEmpty {
                    Spacer()
                    OpenTicketsEmptyView()
                    Spacer()
                } else {
                    List(displayedTickets) { ticket in
                        NavigationLink(value: ticket) {
                            TicketRowView(ticket: ticket, isAdmin: stateManager.isAdmin)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .listStyle(.plain)
                    .contentMargins(.top, AppChrome.contentSpacing, for: .scrollContent)
                    .contentMargins(.bottom, 88, for: .scrollContent)
                    .scrollContentBackground(.hidden)
                    .scrollUnderBarShadow()
                    .refreshable { stateManager.refreshAllTicketData() }
                }
            }

            if !stateManager.isAdmin {
                CompletedTicketsToggleButton(showCompleted: showCompletedTickets) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCompletedTickets.toggle()
                    }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 28)
                .zIndex(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { configureTopBar() }
        .sheet(isPresented: $state.showCreateTicketSheet) {
            CreateTicketView()
                .environment(stateManager)
        }
        .navigationDestination(for: Ticket.self) { ticket in
            TicketDetailView(ticket: ticket)
                .environment(stateManager)
        }
    }

    private func configureTopBar() {
        stateManager.topBarShowsBack = false
        stateManager.topBarBackHandler = nil
        stateManager.topBarShowsCreate = true
    }
}

struct CompletedTicketsToggleButton: View {
    let showCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: showCompleted ? "eye" : "eye.slash")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.72))
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                )
        }
        .accessibilityLabel(showCompleted ? "Hide completed tickets" : "Show completed tickets")
    }
}

struct TicketRowView: View {
    @Environment(AppStateManager.self) private var stateManager
    let ticket: Ticket
    let isAdmin: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.title)
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if !ticket.description.isEmpty {
                        Text(ticket.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                PriorityBadge(priority: ticket.priority)
            }

            HStack {
                StatusBadge(status: ticket.status)
                DepartmentBadge(
                    slug: ticket.department,
                    label: stateManager.label(forDepartment: ticket.department),
                    colorIndex: stateManager.departments.firstIndex(where: { $0.slug == ticket.department }) ?? 0
                )
                if isAdmin {
                    Text(ticket.user_email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(ticket.created_at, format: TicketTimestamp.format)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .subtleCardGradient()
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}
