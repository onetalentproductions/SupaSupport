import SwiftUI
import AVFoundation
import AuthenticationServices
import CryptoKit

struct ConnectView: View {
    @Environment(AppStateManager.self) private var stateManager
    @State private var pastedPayload = ""
    @State private var showScanner = false
    @State private var appleSignInNonce = ""

    private var isConnected: Bool {
        stateManager.isConnected
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 24)

                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(isConnected ? stateManager.orgName : AppConfig.appName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                if isConnected {
                    connectedSignInSection
                } else {
                    connectOrganizationSection
                }

                if let error = stateManager.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.subheadline.bold())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer(minLength: 24)
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { code in
                pastedPayload = code
                showScanner = false
                Task { await stateManager.connect(with: code) }
            }
        }
    }

    private var connectOrganizationSection: some View {
        Group {
            Text("Supabase-backed support for your team")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text("Scan your organization's QR code or paste the connection payload from your admin.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showScanner = true
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("Or paste connection JSON")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.8))
                TextEditor(text: $pastedPayload)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            Button {
                Task { await stateManager.connect(with: pastedPayload) }
            } label: {
                Text(stateManager.isLoading ? "Connecting…" : "Connect")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent.opacity(pastedPayload.isEmpty ? 0.35 : 1))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(pastedPayload.isEmpty || stateManager.isLoading)
            .padding(.horizontal, 32)

            Link(destination: AppConfig.setupURL) {
                Text("Set up a new organization →")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.accentLight)
            }
        }
    }

    private var connectedSignInSection: some View {
        Group {
            Text("Organization connected")
                .font(.subheadline)
                .foregroundStyle(AppTheme.accentLight)

            Text("Sign in with Google or Apple to continue.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
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

            Button {
                Task { await stateManager.signInWithGoogle() }
            } label: {
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

            Button("Connect a different organization") {
                Task { await stateManager.disconnectOrganization() }
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.top, 8)

            if stateManager.errorMessage != nil {
                Button("Choose a different account") {
                    stateManager.switchGoogleAccount()
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            }
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

struct QRScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        session.startRunning()
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        session.stopRunning()
        onCode?(value)
        dismiss(animated: true)
    }
}
