import Foundation
import GoogleSignIn
import Supabase
import UIKit

@Observable
class AppStateManager {
    var isConnected = TenantManager.shared.isConnected
    var isLoggedIn = false
    var orgName = TenantManager.shared.config?.orgName ?? AppConfig.appName
    var departments: [Department] = []
    var userTickets: [Ticket] = []
    var archivedTickets: [Ticket] = []
    var departmentCompletions: [DepartmentCompletion] = []
    var errorMessage: String?
    var isLoading = false
    var currentUserId: UUID?
    var currentUserEmail: String?
    var isAdmin = false
    var adminDepartmentSlugs: [String] = []
    var topBarShowsCreate = false
    var topBarShowsBack = false
    var showCreateTicketSheet = false
    var showInviteUserSheet = false
    @ObservationIgnored var topBarBackHandler: (() -> Void)?

    private static let signInNotAllowedMessage =
        "Sign-in was not allowed for this account. Ask your admin for an invite."

    init() {
        isConnected = TenantManager.shared.isConnected
        guard TenantManager.shared.isConnected else { return }
        Task {
            let session = try? await TenantManager.shared.supabase.auth.session
            await MainActor.run {
                if let session {
                    Task { await self.bootstrapAfterSignIn(session: session, email: userDisplayEmail(session: session)) }
                }
            }
        }
    }

    var defaultDepartmentSlug: String {
        departments.first?.slug ?? "facilities"
    }

    var showsDepartmentPicker: Bool {
        departments.count > 1
    }

    func label(forDepartment slug: String) -> String {
        departments.first(where: { $0.slug == slug })?.label ?? slug.capitalized
    }

    @MainActor
    func connect(with rawPayload: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let (config, invite) = try ConnectPayloadParser.parse(rawPayload)
            TenantManager.shared.connect(config: config, inviteToken: invite)
            isConnected = true
            orgName = config.orgName
            try? await TenantManager.shared.supabase.auth.signOut()
            isLoggedIn = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func disconnectOrganization() async {
        await signOutFully()
        TenantManager.shared.disconnect()
        isConnected = false
        orgName = AppConfig.appName
        departments = []
    }

    @MainActor
    private func bootstrapAfterSignIn(session: Session, email: String?) async {
        isLoading = true
        errorMessage = nil
        do {
            departments = try await OrgService.fetchDepartments()
            orgName = (try? await OrgService.fetchOrgName()) ?? TenantManager.shared.config?.orgName ?? AppConfig.appName
            let membership = try await OrgService.redeemInviteIfNeeded()
            guard membership.role != nil else {
                throw OrgServiceError.notAMember
            }
            applySession(session, email: email, membership: membership)
            refreshAllTicketData()
            await PushNotificationService.shared.registerAfterSignIn()
            isLoggedIn = true
        } catch {
            try? await TenantManager.shared.supabase.auth.signOut()
            errorMessage = error.localizedDescription
            isLoggedIn = false
        }
        isLoading = false
    }

    @MainActor
    private func applySession(_ session: Session, email: String? = nil, membership: OrgMembership) {
        let resolvedEmail = email ?? userDisplayEmail(session: session)
        currentUserId = session.user.id
        currentUserEmail = resolvedEmail
        isAdmin = membership.isAdmin
        adminDepartmentSlugs = membership.department_slugs
    }

    @MainActor
    func signInWithGoogle() async {
        guard TenantManager.shared.isConnected else {
            errorMessage = "Connect to your organization first."
            return
        }

        isLoading = true
        errorMessage = nil

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            isLoading = false
            return
        }

        clearGoogleSession()

        guard GoogleAuth.isWebClientIDConfigured else {
            errorMessage = "Google Web Client ID is not configured."
            isLoading = false
            return
        }

        do {
            let signInResult = try await GoogleAuth.signIn(presenting: rootViewController)
            guard let idToken = signInResult.user.idToken?.tokenString else {
                errorMessage = "Google sign-in did not return an ID token."
                isLoading = false
                return
            }

            let googleEmail = signInResult.user.profile?.email
                .lowercased()
                .trimmingCharacters(in: .whitespaces)

            let session = try await TenantManager.shared.supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: signInResult.user.accessToken.tokenString,
                    nonce: signInResult.rawNonce
                )
            )

            await bootstrapAfterSignIn(
                session: session,
                email: userDisplayEmail(session: session, preferred: googleEmail)
            )
        } catch {
            clearGoogleSession()
            try? await TenantManager.shared.supabase.auth.signOut()
            errorMessage = Self.authErrorMessage(for: error)
            isLoggedIn = false
        }

        isLoading = false
    }

    @MainActor
    func completeAppleSignIn(idToken: String, rawNonce: String, email: String?) async {
        guard TenantManager.shared.isConnected else {
            errorMessage = "Connect to your organization first."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let session = try await TenantManager.shared.supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: rawNonce
                )
            )

            await bootstrapAfterSignIn(
                session: session,
                email: userDisplayEmail(session: session, preferred: email?.lowercased())
            )
        } catch {
            try? await TenantManager.shared.supabase.auth.signOut()
            errorMessage = Self.authErrorMessage(for: error)
            isLoggedIn = false
        }

        isLoading = false
    }

    @MainActor
    func switchGoogleAccount() {
        errorMessage = nil
        clearGoogleSession()
        Task { await signOutFully() }
    }

    func signOut() {
        Task { await signOutFully() }
    }

    @MainActor
    private func signOutFully() async {
        await PushNotificationService.shared.removeStoredDeviceToken()
        clearGoogleSession()
        try? await TenantManager.shared.supabase.auth.signOut()
        isLoggedIn = false
        userTickets = []
        archivedTickets = []
        departmentCompletions = []
        currentUserId = nil
        currentUserEmail = nil
        isAdmin = false
        adminDepartmentSlugs = []
        errorMessage = nil
    }

    private func clearGoogleSession() {
        GIDSignIn.sharedInstance.signOut()
    }

    func refreshAllTicketData() {
        fetchTickets()
        fetchArchivedTickets()
        fetchDepartmentCompletionCounts()
    }

    func fetchTickets() {
        Task {
            do {
                let fetched = try await TicketService.fetchActiveTickets(
                    forUserId: currentUserId,
                    isAdmin: isAdmin,
                    adminDepartmentSlugs: adminDepartmentSlugs
                )
                await MainActor.run {
                    userTickets = fetched
                }
            } catch {
                print("Database retrieval error: \(error)")
            }
        }
    }

    func fetchArchivedTickets() {
        guard isAdmin else { return }
        Task {
            do {
                let slugs = adminDepartmentSlugs.isEmpty
                    ? departments.map(\.slug)
                    : adminDepartmentSlugs
                let fetched = try await TicketService.fetchArchivedTickets(departmentSlugs: slugs)
                await MainActor.run {
                    archivedTickets = fetched
                }
            } catch {
                print("Archive retrieval error: \(error)")
            }
        }
    }

    func fetchDepartmentCompletionCounts() {
        guard isAdmin else { return }
        Task {
            do {
                let counts = try await OrgService.fetchDepartmentCompletionCounts()
                await MainActor.run {
                    departmentCompletions = counts
                }
            } catch {
                print("Department completion counts error: \(error)")
            }
        }
    }

    var allDepartmentTickets: [Ticket] {
        let activeIds = Set(userTickets.map(\.id))
        let archivedOnly = archivedTickets.filter { !activeIds.contains($0.id) }
        return userTickets + archivedOnly
    }

    var dashboardAnalytics: DashboardAnalytics {
        TicketService.computeDashboardAnalytics(
            activeTickets: userTickets,
            archivedTickets: archivedTickets,
            adminEmail: currentUserEmail,
            departmentCompletions: departmentCompletions
        )
    }

    private static func authErrorMessage(for error: Error) -> String {
        let description = String(describing: error).lowercased()
        let localized = error.localizedDescription

        if localized.lowercased().contains("invite")
            || localized.lowercased().contains("membership")
            || localized.lowercased().contains("not allowed") {
            return signInNotAllowedMessage
        }

        if description.contains("unacceptable audience") {
            return "Supabase rejected the Google token. Check Google provider settings for this Supabase project."
        }

        return "Sign-in failed: \(localized)"
    }
}
