import SwiftUI
import AVFoundation

struct ConnectView: View {
    @Environment(AppStateManager.self) private var stateManager
    @State private var pastedPayload = ""
    @State private var showScanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 24)

                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text(AppConfig.appName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

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
                        .background(Color.white)
                        .foregroundStyle(.primary)
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
                        .background(Color.white.opacity(pastedPayload.isEmpty ? 0.35 : 1))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(pastedPayload.isEmpty || stateManager.isLoading)
                .padding(.horizontal, 32)

                Link(destination: AppConfig.setupURL) {
                    Text("Set up a new organization →")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
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
