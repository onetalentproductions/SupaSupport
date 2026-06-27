import SwiftUI
import Charts

struct AdminAnalyticsView: View {
    @Environment(AppStateManager.self) private var stateManager

    private var analytics: DashboardAnalytics { stateManager.dashboardAnalytics }

    private let levelColors: [String: Color] = [
        "Low": .green,
        "Medium": AppTheme.accent,
        "High": .orange,
        "Out of Scope": .purple
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                adminScoreCard
                departmentCompletionBar
                monthlySubmissionsCard
                topSubmittersCard
                levelBreakdownCard
            }
            .padding(.vertical)
        }
        .scrollUnderBarShadow()
        .refreshable { stateManager.refreshAllTicketData() }
        .onAppear { configureTopBar() }
        .onDisappear { clearTopBar() }
    }

    private var departmentCompletionBar: some View {
        DepartmentCompletionBar(completions: analytics.departmentCompletions)
    }

    private var adminScoreCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("\(analytics.adminCompletedCount)")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)

            Text("Tickets Closed by You")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let email = stateManager.currentUserEmail {
                Text(displayName(for: email))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .analyticsPanel()
        .padding(.horizontal)
    }

    private var monthlySubmissionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Submissions")
                .font(.headline)
                .foregroundStyle(.primary)

            if analytics.monthlySubmissions.allSatisfy({ $0.count == 0 }) {
                Text("No tickets submitted yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            } else {
                Chart(analytics.monthlySubmissions) { month in
                    BarMark(
                        x: .value("Month", month.label),
                        y: .value("Tickets", month.count)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.accentLight, AppTheme.accentDark],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .analyticsPanel()
        .padding(.horizontal)
    }

    private var topSubmittersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Submitters")
                .font(.headline)
                .foregroundStyle(.primary)

            if analytics.topSubmitters.isEmpty {
                Text("No submitters yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(analytics.topSubmitters.enumerated()), id: \.element.id) { index, submitter in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(AppTheme.accent.opacity(0.85)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName(for: submitter.email))
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(submitter.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("\(submitter.count)")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        Text(submitter.count == 1 ? "ticket" : "tickets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    if index < analytics.topSubmitters.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .analyticsPanel()
        .padding(.horizontal)
    }

    private var levelBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ticket Levels")
                .font(.headline)
                .foregroundStyle(.primary)

            if analytics.levelSlices.isEmpty {
                Text("No ticket data yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    Chart(analytics.levelSlices) { slice in
                        SectorMark(
                            angle: .value("Tickets", slice.count),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .foregroundStyle(levelColors[slice.label] ?? .gray)
                    }
                    .frame(width: 150, height: 150)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(analytics.levelSlices) { slice in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(levelColors[slice.label] ?? .gray)
                                    .frame(width: 10, height: 10)
                                Text(slice.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(slice.count)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .analyticsPanel()
        .padding(.horizontal)
    }

    private func displayName(for email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? email
        return local.replacingOccurrences(of: ".", with: " ").capitalized
    }

    private func configureTopBar() {
        stateManager.topBarShowsCreate = false
        stateManager.topBarShowsBack = false
        stateManager.topBarBackHandler = nil
    }

    private func clearTopBar() {
        stateManager.topBarShowsCreate = true
    }
}
