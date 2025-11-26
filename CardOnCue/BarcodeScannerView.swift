import SwiftUI
import AVFoundation
import SwiftData
import Combine

struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var scanner = BarcodeScannerViewModel()
    @State private var showingManualEntry = false
    @State private var scannedCode: String?
    @State private var detectedBarcodeType: BarcodeType?
    @State private var showingSaveSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                CameraPreviewView(session: scanner.session)
                    .ignoresSafeArea()

                // Overlay
                VStack {
                    // Top gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.6),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)

                    Spacer()

                    // Scanning frame
                    VStack(spacing: 16) {
                        Text("Position barcode within frame")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)

                        // Scanning rectangle
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(scanner.isScanning ? Color.appGreen : Color.white, lineWidth: 3)
                                .frame(width: 280, height: 180)

                            // Corner indicators
                            ScannerCorners()
                        }
                        .frame(height: 200)
                    }

                    Spacer()

                    // Bottom controls gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.black.opacity(0.6)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 180)
                    .overlay(
                        VStack(spacing: 16) {
                            Spacer()

                            // Flash toggle
                            if scanner.hasFlash {
                                Button(action: { scanner.toggleFlash() }) {
                                    Image(systemName: scanner.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                            }

                            // Manual entry button
                            Button(action: {
                                showingManualEntry = true
                            }) {
                                Text("Enter Manually")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(20)
                            }
                            .padding(.bottom, 32)
                        }
                    )
                }

                // Success overlay
                if scanner.scanSuccess {
                    Color.appGreen.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            VStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.white)
                                Text("Barcode Scanned!")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        scanner.stopScanning()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .principal) {
                    Text("Scan Card")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(Color.black.opacity(0.6), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                scanner.startScanning()
            }
            .onDisappear {
                scanner.stopScanning()
            }
            .onChange(of: scanner.scannedCode) { oldValue, newValue in
                if let code = newValue, let type = scanner.detectedType {
                    handleScannedCode(code, type: type)
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
            .sheet(isPresented: $showingSaveSheet) {
                if let code = scannedCode, let type = detectedBarcodeType {
                    ScannedCardReviewView(
                        barcodeNumber: code,
                        barcodeType: type,
                        onSave: {
                            dismiss()
                        },
                        onRescan: {
                            showingSaveSheet = false
                            scanner.resetScanning()
                        }
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func handleScannedCode(_ code: String, type: BarcodeType) {
        scannedCode = code
        detectedBarcodeType = type
        showingSaveSheet = true
    }
}

// MARK: - Scanner View Model

class BarcodeScannerViewModel: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var detectedType: BarcodeType?
    @Published var isScanning = false
    @Published var scanSuccess = false
    @Published var isFlashOn = false
    @Published var hasFlash = false

    let session = AVCaptureSession()
    private var videoDevice: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "com.cardoncue.scanner")

    override init() {
        super.init()
        checkCameraPermission()
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupCamera()
                }
            }
        default:
            break
        }
    }

    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.session.beginConfiguration()

            // Get video device
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.session.commitConfiguration()
                return
            }

            self.videoDevice = videoDevice

            // Check if device has flash
            DispatchQueue.main.async {
                self.hasFlash = videoDevice.hasTorch
            }

            // Add video input
            guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoInput) else {
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(videoInput)

            // Add metadata output for barcode scanning
            let metadataOutput = AVCaptureMetadataOutput()

            guard self.session.canAddOutput(metadataOutput) else {
                self.session.commitConfiguration()
                return
            }

            self.session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

            // Set supported barcode types
            metadataOutput.metadataObjectTypes = [
                .qr,
                .code128,
                .pdf417,
                .aztec,
                .ean13,
                .upce,
                .code39,
                .itf14
            ]

            self.session.commitConfiguration()
        }
    }

    func startScanning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }

        DispatchQueue.main.async {
            self.isScanning = true
        }
    }

    func stopScanning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }

        DispatchQueue.main.async {
            self.isScanning = false
        }
    }

    func resetScanning() {
        scannedCode = nil
        detectedType = nil
        scanSuccess = false
        startScanning()
    }

    func toggleFlash() {
        guard let device = videoDevice, device.hasTorch else { return }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                try device.lockForConfiguration()

                if device.torchMode == .on {
                    device.torchMode = .off
                    DispatchQueue.main.async {
                        self.isFlashOn = false
                    }
                } else {
                    try device.setTorchModeOn(level: 1.0)
                    DispatchQueue.main.async {
                        self.isFlashOn = true
                    }
                }

                device.unlockForConfiguration()
            } catch {
                print("Flash error: \(error)")
            }
        }
    }
}

// MARK: - Metadata Delegate

extension BarcodeScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Ignore if already scanned
        guard scannedCode == nil else { return }

        // Get first barcode
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadataObject.stringValue else {
            return
        }

        // Map AVMetadataObject type to BarcodeType
        let barcodeType = mapToBarcodeType(metadataObject.type)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Update state
        scannedCode = code
        detectedType = barcodeType
        scanSuccess = true

        // Stop scanning
        stopScanning()
    }

    private func mapToBarcodeType(_ type: AVMetadataObject.ObjectType) -> BarcodeType {
        switch type {
        case .qr:
            return .qr
        case .code128:
            return .code128
        case .pdf417:
            return .pdf417
        case .aztec:
            return .aztec
        case .ean13:
            return .ean13
        case .upce:
            return .upcA
        case .code39:
            return .code39
        case .itf14:
            return .itf
        default:
            return .qr
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill

        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Scanner Corners

struct ScannerCorners: View {
    var body: some View {
        ZStack {
            // Top-left corner
            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appGreen)
                        .frame(width: 30, height: 4)
                    Spacer()
                }
                Spacer()
            }

            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appGreen)
                        .frame(width: 4, height: 30)
                    Spacer()
                }
                Spacer()
            }

            // Top-right corner
            VStack {
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appGreen)
                        .frame(width: 30, height: 4)
                }
                Spacer()
            }

            VStack {
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appGreen)
                        .frame(width: 4, height: 30)
                }
                Spacer()
            }

            // Bottom-left corner
            VStack {
                Spacer()
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appGreen)
                        .frame(width: 30, height: 4)
                    Spacer()
                }
            }

            VStack {
                Spacer()
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appGreen)
                        .frame(width: 4, height: 30)
                    Spacer()
                }
            }

            // Bottom-right corner
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appGreen)
                        .frame(width: 30, height: 4)
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.appGreen)
                        .frame(width: 4, height: 30)
                }
            }
        }
        .frame(width: 280, height: 180)
    }
}

#Preview {
    BarcodeScannerView()
        .modelContainer(for: CardModel.self, inMemory: true)
}
