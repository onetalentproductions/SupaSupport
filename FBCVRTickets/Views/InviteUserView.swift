import SwiftUI

struct InviteUserView: View {
    @Environment(AppStateManager.self) private var stateManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var roleIsAdmin = false
    @State private var selectedSlugs: Set<String> = []
    @State private var generatedPayload = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("User") {
                    TextField("Email (optional)", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    Toggle("Admin", isOn: $roleIsAdmin)
                }

                if stateManager.departments.count > 1 {
                    Section("Departments") {
                        ForEach(stateManager.departments) { dept in
                            Toggle(dept.label, isOn: binding(for: dept.slug))
                        }
                    }
                }

                Section {
                    Button(isLoading ? "Working…" : "Add by email") {
                        Task { await addByEmail() }
                    }
                    .disabled(isLoading || email.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button(isLoading ? "Working…" : "Generate invite QR / link") {
                        Task { await generateInvite() }
                    }
                    .disabled(isLoading)
                }

                if !generatedPayload.isEmpty {
                    Section("Share this connection payload") {
                        Text(generatedPayload)
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add User")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if selectedSlugs.isEmpty {
                    selectedSlugs = Set(stateManager.departments.map(\.slug))
                }
            }
        }
    }

    private func binding(for slug: String) -> Binding<Bool> {
        Binding(
            get: { selectedSlugs.contains(slug) },
            set: { isOn in
                if isOn { selectedSlugs.insert(slug) } else { selectedSlugs.remove(slug) }
            }
        )
    }

    private var departmentSlugs: [String] {
        let slugs = Array(selectedSlugs)
        if slugs.isEmpty { return stateManager.departments.map(\.slug) }
        return slugs
    }

    private func addByEmail() async {
        isLoading = true
        errorMessage = nil
        do {
            try await OrgService.addPendingMember(
                email: email,
                role: roleIsAdmin ? "admin" : "user",
                departmentSlugs: departmentSlugs
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func generateInvite() async {
        isLoading = true
        errorMessage = nil
        do {
            let token = try await OrgService.createInvite(
                role: roleIsAdmin ? "admin" : "user",
                departmentSlugs: departmentSlugs,
                email: email.nilIfEmpty
            )
            generatedPayload = OrgService.buildInvitePayload(token: token)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
