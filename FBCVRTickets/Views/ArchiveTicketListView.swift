import SwiftUI

struct ArchiveTicketListView: View {
    @Environment(AppStateManager.self) private var stateManager

    var body: some View {
        @Bindable var state = stateManager

        VStack(spacing: 0) {
            if stateManager.archivedTickets.isEmpty {
                Spacer()
                OpenTicketsEmptyView(title: "No archived tickets", systemImage: "archivebox")
                Spacer()
            } else {
                List(stateManager.archivedTickets) { ticket in
                    NavigationLink(value: ticket) {
                        TicketRowView(ticket: ticket, isAdmin: true)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .listStyle(.plain)
                .contentMargins(.top, AppChrome.contentSpacing, for: .scrollContent)
                .scrollContentBackground(.hidden)
                .scrollUnderBarShadow()
                .refreshable {
                    stateManager.fetchArchivedTickets()
                    stateManager.fetchDepartmentCompletionCounts()
                }
            }
        }
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
