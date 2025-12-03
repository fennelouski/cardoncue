import SwiftUI
import AVFoundation
import SwiftData
import Combine
import Vision

// MARK: - Device Performance Tier

enum DevicePerformanceTier {
    case high    // M-series iPads, iPhone 15 Pro+, 8+ cores, 6GB+ RAM
    case medium  // iPhone 13-15, iPad Air, 4-6 cores, 4GB+ RAM
    case low     // Older devices, <4 cores or <4GB RAM
}

// MARK: - Detected Barcode Model

struct DetectedBarcodeData: Hashable {
    let barcodeType: BarcodeType
    let payload: String
    let confidence: Double
    let detectedSymbology: String
    let boundingBox: CGRect

    init(barcodeType: BarcodeType, payload: String, confidence: Double, detectedSymbology: String, boundingBox: CGRect) {
        self.barcodeType = barcodeType
        self.payload = payload
        self.confidence = confidence
        self.detectedSymbology = detectedSymbology
        self.boundingBox = boundingBox
    }
}

// MARK: - Barcode Quality Metrics

struct BarcodeQualityMetrics: Codable, Hashable {
    var readabilityScore: Double
    var imageSharpness: Double
    var contrastScore: Double
    var overallScore: Double

    init(
        readabilityScore: Double = 0.0,
        imageSharpness: Double = 0.0,
        contrastScore: Double = 0.0
    ) {
        self.readabilityScore = readabilityScore
        self.imageSharpness = imageSharpness
        self.contrastScore = contrastScore
        self.overallScore = (readabilityScore + imageSharpness + contrastScore) / 3.0
    }
}

// MARK: - Captured Frame Model

struct CapturedFrame {
    let image: UIImage
    let timestamp: Date
    var barcodeData: DetectedBarcodeData?
    var qualityScore: Double

    init(image: UIImage, timestamp: Date, barcodeData: DetectedBarcodeData? = nil, qualityScore: Double = 0.0) {
        self.image = image
        self.timestamp = timestamp
        self.barcodeData = barcodeData
        self.qualityScore = qualityScore
    }
}

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
                                .stroke(scanner.barcodeDetected ? Color.appGreen : (scanner.isScanning ? Color.white.opacity(0.8) : Color.white), lineWidth: 3)
                                .frame(width: 280, height: 180)
                                .animation(.easeInOut(duration: 0.3), value: scanner.barcodeDetected)

                            // Corner indicators
                            ScannerCorners(isDetected: scanner.barcodeDetected)
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

                            // Show Continue button when barcode detected
                            if scanner.barcodeDetected && !scanner.scanSuccess {
                                Button(action: {
                                    scanner.confirmBarcodeSelection()
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                        Text("Continue")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.appPrimary)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal, 24)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            } else if !scanner.scanSuccess {
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
                            }

                            Spacer()
                                .frame(height: 32)
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
                        capturedImage: scanner.bestCapturedImage,
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
    @Published var barcodeDetected = false  // New: indicates barcode found, awaiting user confirmation
    @Published var bestCapturedImage: UIImage?  // New: best quality frame captured

    let session = AVCaptureSession()
    private var videoDevice: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "com.cardoncue.scanner")
    private let frameProcessingQueue = DispatchQueue(label: "com.cardoncue.frameprocessing", qos: .userInitiated)

    // Frame buffer to store recent frames (last 2 seconds at ~10fps = 20 frames)
    private var frameBuffer: [CapturedFrame] = []
    private let maxBufferSize = 20
    private let bufferTimeWindow: TimeInterval = 2.0

    // Track when barcode was first detected
    private var barcodeFirstDetectedAt: Date?
    private var detectedBarcodePayload: String?

    // Auto-select timeout (if user doesn't press button within 3 seconds)
    private var autoSelectTimer: Timer?

    // Dynamic frame throttling for performance
    private var frameCounter = 0
    private var frameSkipCount = 3  // Initial value, will be adjusted dynamically
    private var lastFrameProcessTime: Date?
    private var averageProcessingTime: TimeInterval = 0.0
    private let maxProcessingTime: TimeInterval = 0.1  // 100ms budget per frame

    override init() {
        super.init()
        configureAdaptiveThrottling()
        setupThermalStateMonitoring()
        checkCameraPermission()
    }

    // MARK: - Adaptive Performance Configuration

    private func configureAdaptiveThrottling() {
        let performanceTier = getDevicePerformanceTier()

        switch performanceTier {
        case .high:
            // High-end devices: M-series iPads, iPhone 15 Pro+, iPhone 14 Pro+
            frameSkipCount = 1  // Process every 2nd frame (~15 fps)
        case .medium:
            // Mid-range: iPhone 13-15, iPad Air, recent devices
            frameSkipCount = 2  // Process every 3rd frame (~10 fps)
        case .low:
            // Older devices: iPhone 11 and earlier, older iPads
            frameSkipCount = 4  // Process every 5th frame (~6 fps)
        }

        print("📊 Device performance tier: \(performanceTier), initial skip count: \(frameSkipCount)")
    }

    private func getDevicePerformanceTier() -> DevicePerformanceTier {
        let processorCount = ProcessInfo.processInfo.processorCount
        let physicalMemory = ProcessInfo.processInfo.physicalMemory

        // Use CPU core count and RAM as performance indicators
        // High-end: 6+ performance cores, 6GB+ RAM
        if processorCount >= 8 && physicalMemory >= 6_000_000_000 {
            return .high
        }
        // Medium: 4-6 cores, 4GB+ RAM
        else if processorCount >= 4 && physicalMemory >= 4_000_000_000 {
            return .medium
        }
        // Low: Everything else
        else {
            return .low
        }
    }

    private func setupThermalStateMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    @objc private func thermalStateChanged() {
        let thermalState = ProcessInfo.processInfo.thermalState

        // Adjust throttling based on thermal state
        switch thermalState {
        case .nominal:
            // Normal temperature - no adjustment needed
            break
        case .fair:
            // Slightly elevated - increase throttling by 1
            frameSkipCount = min(frameSkipCount + 1, 7)
            print("🌡️ Thermal state: Fair, increasing throttling to \(frameSkipCount)")
        case .serious, .critical:
            // High temperature - aggressive throttling
            frameSkipCount = 7  // Process every 8th frame
            print("🌡️ Thermal state: \(thermalState == .serious ? "Serious" : "Critical"), maximum throttling")
        @unknown default:
            break
        }
    }

    private func adjustThrottlingBasedOnPerformance(_ processingTime: TimeInterval) {
        // Exponential moving average for smoothing
        let alpha = 0.3
        averageProcessingTime = alpha * processingTime + (1 - alpha) * averageProcessingTime

        // Adjust throttling based on how we're doing against our time budget
        if averageProcessingTime > maxProcessingTime * 1.5 {
            // We're struggling - increase throttling
            frameSkipCount = min(frameSkipCount + 1, 7)
            print("⚠️ Slow processing (\(Int(averageProcessingTime * 1000))ms), increasing skip to \(frameSkipCount)")
        } else if averageProcessingTime < maxProcessingTime * 0.5 && frameSkipCount > 1 {
            // We have headroom - reduce throttling for better quality
            frameSkipCount = max(frameSkipCount - 1, 1)
            print("✅ Fast processing (\(Int(averageProcessingTime * 1000))ms), reducing skip to \(frameSkipCount)")
        }
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

            // Add video data output for frame capture
            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(self, queue: self.frameProcessingQueue)
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            // Drop frames if processing is too slow to avoid backup
            videoDataOutput.alwaysDiscardsLateVideoFrames = true

            if self.session.canAddOutput(videoDataOutput) {
                self.session.addOutput(videoDataOutput)
            }

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
        barcodeDetected = false
        bestCapturedImage = nil
        barcodeFirstDetectedAt = nil
        detectedBarcodePayload = nil
        frameBuffer.removeAll()
        autoSelectTimer?.invalidate()
        autoSelectTimer = nil
        startScanning()
    }

    // Called when user confirms they want to use the detected barcode
    func confirmBarcodeSelection() {
        guard let payload = detectedBarcodePayload else { return }

        // Find the best frame within ±500ms of now
        let now = Date()
        let windowStart = now.addingTimeInterval(-0.5)
        let windowEnd = now.addingTimeInterval(0.5)

        let framesInWindow = frameBuffer.filter { frame in
            frame.timestamp >= windowStart && frame.timestamp <= windowEnd &&
            frame.barcodeData != nil &&
            frame.barcodeData?.payload == payload
        }

        // Select the frame with the highest quality score
        if let bestFrame = framesInWindow.max(by: { $0.qualityScore < $1.qualityScore }) {
            DispatchQueue.main.async {
                self.bestCapturedImage = bestFrame.image
                self.scannedCode = payload
                self.detectedType = bestFrame.barcodeData?.barcodeType
                self.scanSuccess = true
                self.stopScanning()
            }
        } else {
            // Fallback: use the best frame we have overall
            if let bestFrame = frameBuffer.filter({ $0.barcodeData?.payload == payload }).max(by: { $0.qualityScore < $1.qualityScore }) {
                DispatchQueue.main.async {
                    self.bestCapturedImage = bestFrame.image
                    self.scannedCode = payload
                    self.detectedType = bestFrame.barcodeData?.barcodeType
                    self.scanSuccess = true
                    self.stopScanning()
                }
            }
        }
    }

    // Manage frame buffer - keep only recent frames
    private func addToFrameBuffer(_ frame: CapturedFrame) {
        frameBuffer.append(frame)

        // Remove frames older than the time window
        let cutoffTime = Date().addingTimeInterval(-bufferTimeWindow)
        frameBuffer.removeAll { $0.timestamp < cutoffTime }

        // Ensure we don't exceed max buffer size
        if frameBuffer.count > maxBufferSize {
            frameBuffer.removeFirst(frameBuffer.count - maxBufferSize)
        }
    }

    deinit {
        autoSelectTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
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

// MARK: - Video Data Delegate

extension BarcodeScannerViewModel: @preconcurrency AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Don't process if we've already confirmed a selection
        guard scannedCode == nil else { return }

        // Adaptive frame throttling: only process every Nth frame
        frameCounter += 1
        guard frameCounter % (frameSkipCount + 1) == 0 else { return }

        // Convert sample buffer to UIImage
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let image = UIImage(pixelBuffer: pixelBuffer) else {
            return
        }

        let timestamp = Date()
        let processingStartTime = Date()

        // Evaluate barcode quality in this frame asynchronously
        Task {
            let barcodeData = await BarcodeQualityService.shared.detectBestBarcode(in: image)

            // Calculate quality score based on barcode confidence
            let qualityScore = barcodeData?.confidence ?? 0.0

            let frame = CapturedFrame(
                image: image,
                timestamp: timestamp,
                barcodeData: barcodeData,
                qualityScore: qualityScore
            )

            // Measure processing time and adjust throttling
            let processingTime = Date().timeIntervalSince(processingStartTime)

            // Add to buffer and adjust throttling on main queue
            DispatchQueue.main.async {
                self.addToFrameBuffer(frame)
                self.adjustThrottlingBasedOnPerformance(processingTime)
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
        // Ignore if already showing confirmation or completed
        guard !barcodeDetected && scannedCode == nil else { return }

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

        // Update state to show Continue button (but keep scanning!)
        barcodeDetected = true
        detectedBarcodePayload = code
        detectedType = barcodeType
        barcodeFirstDetectedAt = Date()

        // Start auto-select timer (3 seconds)
        autoSelectTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.confirmBarcodeSelection()
            }
        }
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
    var isDetected: Bool = false

    var body: some View {
        let cornerColor = isDetected ? Color.appGreen : Color.appGreen

        ZStack {
            // Top-left corner
            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(cornerColor)
                        .frame(width: 30, height: 4)
                    Spacer()
                }
                Spacer()
            }

            VStack {
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(cornerColor)
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
                        .fill(cornerColor)
                        .frame(width: 30, height: 4)
                }
                Spacer()
            }

            VStack {
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(cornerColor)
                        .frame(width: 4, height: 30)
                }
                Spacer()
            }

            // Bottom-left corner
            VStack {
                Spacer()
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(cornerColor)
                        .frame(width: 30, height: 4)
                    Spacer()
                }
            }

            VStack {
                Spacer()
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(cornerColor)
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
                        .fill(cornerColor)
                        .frame(width: 30, height: 4)
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(cornerColor)
                        .frame(width: 4, height: 30)
                }
            }
        }
        .frame(width: 280, height: 180)
        .animation(.easeInOut(duration: 0.3), value: isDetected)
    }
}

// MARK: - UIImage Extension for Pixel Buffer Conversion

extension UIImage {
    convenience init?(pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        self.init(cgImage: cgImage)
    }
}

#Preview {
    BarcodeScannerView()
        .modelContainer(for: CardModel.self, inMemory: true)
}
