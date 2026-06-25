import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

enum AppleAuth {
    struct SignInResult {
        let idToken: String
        let rawNonce: String
        let email: String?
        let fullName: PersonNameComponents?
    }

    static func signIn(presenting anchor: ASPresentationAnchor) async throws -> SignInResult {
        let rawNonce = randomNonce()
        let hashedNonce = sha256Hex(rawNonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AuthorizationDelegate()
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        delegate.presentationAnchor = anchor

        let credential = try await delegate.perform(controller: controller)

        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AppleAuthError.missingToken
        }

        return SignInResult(
            idToken: idToken,
            rawNonce: rawNonce,
            email: credential.email,
            fullName: credential.fullName
        )
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            result.append(charset[Int.random(in: 0..<charset.count)])
        }
        return result
    }

    private static func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

enum AppleAuthError: LocalizedError {
    case missingToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingToken: "Apple sign-in did not return an ID token."
        case .cancelled: "Apple sign-in was cancelled."
        }
    }
}

private final class AuthorizationDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    var presentationAnchor: ASPresentationAnchor?
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    func perform(controller: ASAuthorizationController) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AppleAuthError.missingToken)
            continuation = nil
            return
        }
        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
            continuation?.resume(throwing: AppleAuthError.cancelled)
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
