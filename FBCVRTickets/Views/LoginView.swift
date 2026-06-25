import AuthenticationServices
import CryptoKit
import SwiftUI

struct LoginLayoutView: View {
    @Environment(AppStateManager.self) private var stateManager
    @State private var appleSignInNonce = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Text(stateManager.orgName)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Sign in with Google or Apple")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            SignInWithAppleButton(.signIn) { request in
                let nonce = randomNonce()
                appleSignInNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256Hex(nonce)
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .padding(.horizontal, 32)
            .disabled(stateManager.isLoading)

            Button(action: {
                Task { await stateManager.signInWithGoogle() }
            }) {
                HStack(spacing: 12) {
                    if stateManager.isLoading {
                        ProgressView().tint(.primary)
                    } else {
                        Image(systemName: "g.circle.fill").font(.title2)
                        Text("Sign in with Google")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)
            .disabled(stateManager.isLoading)

            Button("Use a different organization") {
                Task { await stateManager.disconnectOrganization() }
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))

            if stateManager.errorMessage != nil {
                Button("Choose a different account") {
                    stateManager.switchGoogleAccount()
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.top, 4)
            }

            if let error = stateManager.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.subheadline.bold())
                    .padding()
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                return
            }
            Task {
                await stateManager.completeAppleSignIn(
                    idToken: idToken,
                    rawNonce: appleSignInNonce,
                    email: credential.email
                )
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                stateManager.errorMessage = "Apple sign-in failed: \(error.localizedDescription)"
            }
        }
    }

    private func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            result.append(charset[Int.random(in: 0..<charset.count)])
        }
        return result
    }

    private func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
