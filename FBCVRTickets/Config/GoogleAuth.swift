import CryptoKit
import Foundation
import GoogleSignIn
import UIKit

enum GoogleAuth {
    struct SignInResult {
        let user: GIDGoogleUser
        let rawNonce: String
    }

    static func configure() {
        guard let iosClientID = iosClientID else {
            print("Google Sign-In: missing CLIENT_ID in GoogleService-Info.plist")
            return
        }

        guard isWebClientIDConfigured else {
            print("Google Sign-In: set AppConfig.googleWebClientID to your Web OAuth client ID")
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: iosClientID)
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: iosClientID,
            serverClientID: AppConfig.googleWebClientID
        )
    }

    static var isWebClientIDConfigured: Bool {
        !AppConfig.googleWebClientID.contains("REPLACE_WITH_YOUR_WEB_CLIENT_ID")
    }

    static func signIn(presenting viewController: UIViewController) async throws -> SignInResult {
        let rawNonce = randomNonce()
        let hashedNonce = sha256Hex(rawNonce)

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController,
                hint: nil,
                additionalScopes: nil,
                nonce: hashedNonce
            ) { signInResult, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let signInResult {
                    continuation.resume(returning: signInResult)
                } else {
                    continuation.resume(throwing: GoogleAuthError.missingResult)
                }
            }
        }

        return SignInResult(user: result.user, rawNonce: rawNonce)
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)

        for _ in 0..<length {
            let index = Int.random(in: 0..<charset.count)
            result.append(charset[index])
        }

        return result
    }

    private static func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static var iosClientID: String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let clientID = dict["CLIENT_ID"] as? String else { return nil }
        return clientID
    }
}

enum GoogleAuthError: LocalizedError {
    case missingResult

    var errorDescription: String? {
        switch self {
        case .missingResult: "Google sign-in returned no result."
        }
    }
}
