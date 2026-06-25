import SwiftUI

let headerBackground = Color.black

enum AppChrome {
    static let barHeight: CGFloat = 56
    static let logoBumpRadius: CGFloat = 38
    static let actionBarHeight: CGFloat = 48
    static let bumpOverlap: CGFloat = 30
    static var totalHeight: CGFloat {
        barHeight + actionBarHeight + bumpOverlap
    }

    static var headerOnlyHeight: CGFloat {
        barHeight + logoBumpRadius
    }

    static let contentSpacing: CGFloat = 12
}

struct AppStartup: View {
    var body: some View {
        LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

/// Fade at the top of a scroll area so content looks like it passes behind the bar above.
struct ScrollUnderBarShadow: View {
    var body: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.2), Color.black.opacity(0.06), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 16)
        .allowsHitTesting(false)
    }
}

extension View {
    func scrollUnderBarShadow() -> some View {
        overlay(alignment: .top) {
            ScrollUnderBarShadow()
        }
    }

    /// Drop shadow for a fixed bar that scrolling content passes behind.
    func scrollOcclusionShadow() -> some View {
        shadow(color: .black.opacity(0.2), radius: 5, y: 3)
    }

    func subtleDarkPanel(topOpacity: Double = 0.16, bottomOpacity: Double = 0.26) -> some View {
        background(
            LinearGradient(
                colors: [
                    Color.black.opacity(topOpacity),
                    Color.black.opacity(bottomOpacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    func subtleLightPanel(topOpacity: Double = 0.1, bottomOpacity: Double = 0.04) -> some View {
        background(
            LinearGradient(
                colors: [
                    Color.white.opacity(topOpacity),
                    Color.white.opacity(bottomOpacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    func subtleCardGradient() -> some View {
        background {
            ZStack {
                Color(.systemBackground)
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.07),
                        Color.clear,
                        Color.blue.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    func analyticsPanel() -> some View {
        background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
    }
}

enum CommentTimestamp {
    static let format: Date.FormatStyle = .dateTime
        .month(.abbreviated)
        .day()
        .hour()
        .minute()
}

enum TicketTimestamp {
    static let format: Date.FormatStyle = CommentTimestamp.format
}

struct CustomHeader: View {
    var title: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(headerBackground)
                .frame(height: AppChrome.barHeight)

            Circle()
                .fill(headerBackground)
                .frame(width: AppChrome.logoBumpRadius * 2, height: AppChrome.logoBumpRadius * 2)
                .offset(y: AppChrome.logoBumpRadius)

            VStack(spacing: 2) {
                Image("Logo")
                    .resizable()
                    .frame(width: 45, height: 45)
                if !title.isEmpty {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .offset(y: AppChrome.logoBumpRadius - 6)
        }
        .frame(height: AppChrome.barHeight + AppChrome.logoBumpRadius)
        .frame(maxWidth: .infinity)
        .background(headerBackground.ignoresSafeArea(edges: .top))
    }
}

struct TopActionBar: View {
    @Environment(AppStateManager.self) private var stateManager

    var body: some View {
        HStack {
            if stateManager.topBarShowsBack {
                Button(action: { stateManager.topBarBackHandler?() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.body.bold())
                        Text("My Tickets")
                            .font(.body.bold())
                    }
                    .foregroundStyle(.white)
                }
            } else {
                Button(action: { stateManager.signOut() }) {
                    Text("Sign Out")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            if stateManager.isAdmin && !stateManager.topBarShowsBack {
                Button(action: { stateManager.showInviteUserSheet = true }) {
                    Label("Add User", systemImage: "person.badge.plus")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                }
            }

            if stateManager.topBarShowsCreate {
                Button(action: { stateManager.showCreateTicketSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("New Ticket")
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, bumpOverlap + 10)
        .frame(height: actionBarHeight + bumpOverlap)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.cyan.opacity(0.9), .blue.opacity(0.9)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    private var bumpOverlap: CGFloat { AppChrome.bumpOverlap }
    private var actionBarHeight: CGFloat { AppChrome.actionBarHeight }
}

struct AppTopChrome: View {
    @Environment(AppStateManager.self) private var stateManager

    var body: some View {
        ZStack(alignment: .top) {
            if stateManager.isLoggedIn {
                TopActionBar()
                    .padding(.top, AppChrome.barHeight)
                    .zIndex(0)
            }

            CustomHeader()
                .zIndex(1)
        }
        .frame(height: stateManager.isLoggedIn ? AppChrome.totalHeight : AppChrome.headerOnlyHeight)
        .scrollOcclusionShadow()
    }
}

struct PriorityBadge: View {
    let priority: TicketPriority

    var body: some View {
        Text(priority.label)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(Capsule().fill(fillColor))
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }

    private var fillColor: Color {
        switch priority {
        case .low: Color(red: 0.12, green: 0.62, blue: 0.38)
        case .medium: Color(red: 0.12, green: 0.42, blue: 0.82)
        case .high: Color(red: 0.82, green: 0.42, blue: 0.08)
        case .urgent: Color(red: 0.78, green: 0.15, blue: 0.18)
        }
    }
}

struct StatusBadge: View {
    let status: TicketStatus

    var body: some View {
        Text(status.label)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(Capsule().fill(fillColor))
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }

    private var fillColor: Color {
        switch status {
        case .open: Color(red: 0.12, green: 0.62, blue: 0.38)
        case .complete: Color(red: 0.38, green: 0.4, blue: 0.44)
        case .outOfScope: Color(red: 0.52, green: 0.22, blue: 0.78)
        }
    }
}

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
        }
    }
}

struct OpenTicketsEmptyView: View {
    let title: String
    let systemImage: String

    init(title: String = "No open tickets", systemImage: String = "ticket") {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .background(Color(.systemGray3).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 24)
    }
}
