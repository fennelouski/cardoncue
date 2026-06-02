import SwiftUI
#if !os(visionOS)
import AVFoundation
#endif
import SwiftData
import Combine
import Vision
import CoreLocation

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

struct CapturedFrame: @unchecked Sendable {
    let image: UIImage
    let timestamp: Date
    var barcodeData: DetectedBarcodeData?
    var qualityScore: Double

    nonisolated init(image: UIImage, timestamp: Date, barcodeData: DetectedBarcodeData? = nil, qualityScore: Double = 0.0) {
        self.image = image
        self.timestamp = timestamp
        self.barcodeData = barcodeData
        self.qualityScore = qualityScore
    }
}

#if !os(visionOS)
struct BarcodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var scanner = BarcodeScannerViewModel()
    @State private var showingManualEntry = false
    @State private var scannedCode: String?
    @State private var detectedBarcodeType: BarcodeType?
    @State private var showingSaveSheet = false
    @State private var capturedImages: [UIImage] = []
    @State private var showingCapturedImages = false
    @State private var showingCapturePreview = false
    @State private var capturedPreviewImage: UIImage?
    @State private var previewImageRotation: Double = 0

    // MARK: - Rapid Scanning Support
    var rapidState: RapidScanningState? = nil
    @State private var isProcessingRapidScan = false
    @State private var rapidScanConfidence: Float = 0.0
    @State private var showingEditSheet = false
    @State private var savedCardToEdit: CardModel?

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview
                CameraPreviewView(session: scanner.session)
                    .ignoresSafeArea()

                // Overlay
                ZStack {
                    VStack {
                        // Top gradient with flashlight button
                        ZStack(alignment: .topTrailing) {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.6),
                                    Color.clear
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 120)
                            
                            // Flashlight button in top corner
                            if scanner.hasFlash {
                                Button(action: { scanner.toggleFlash() }) {
                                    Image(systemName: scanner.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                .padding(.top, 8)
                                .padding(.trailing, 16)
                            }
                        }

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

                        // Bottom controls gradient - extends into safe area
                        GeometryReader { geometry in
                            ZStack(alignment: .bottom) {
                                // Gradient background
                                VStack(spacing: 0) {
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.clear,
                                            Color.black.opacity(0.6)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: 180)
                                    
                                    // Solid extension into safe area
                                    Color.black.opacity(0.6)
                                        .frame(height: geometry.safeAreaInsets.bottom + 20)
                                }
                                
                                // Controls overlay
                                VStack(spacing: 16) {
                                    Spacer()

                                    if !scanner.scanSuccess {
                                        // Show Continue button when barcode detected (only in standard mode)
                                        if scanner.barcodeDetected && (rapidState?.mode == .standard || rapidState == nil) {
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
                                        }
                                        
                                        // Capture button - always visible
                                        Button(action: {
                                            captureImage()
                                        }) {
                                            Image(systemName: "camera.fill")
                                                .font(.title2)
                                                .foregroundColor(.white)
                                                .frame(width: 60, height: 60)
                                                .background(scanner.barcodeDetected ? Color.black.opacity(0.5) : Color.appPrimary)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                                )
                                        }
                                        .padding(.bottom, scanner.barcodeDetected ? 8 : 8)

                                        // Manual entry button
                                        if !scanner.barcodeDetected {
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
                                    }

                                    Spacer()
                                        .frame(height: 32)
                                }
                                .padding(.bottom, geometry.safeAreaInsets.bottom)
                            }
                        }
                        .frame(height: 180)
                        .ignoresSafeArea(edges: .bottom)
                    }
                    
                    // Confidence indicator (standard mode) or confidence meter (rapid mode)
                    if rapidState?.mode == .rapid || rapidState?.mode == .batch {
                        // New confidence meter for rapid/batch mode
                        if isProcessingRapidScan || rapidScanConfidence > 0 {
                            VStack {
                                Spacer()

                                HStack {
                                    ConfidenceMeter(
                                        confidence: rapidScanConfidence,
                                        autoSaveThreshold: rapidState?.autoSaveThreshold ?? 0.85
                                    )
                                    .padding(.leading, 24)

                                    Spacer()
                                }
                                .offset(y: -100)

                                Spacer()
                            }
                        }
                    } else if scanner.barcodeConfidence > 0.0 {
                        // Original confidence indicator for standard mode
                        VStack {
                            Spacer()

                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .opacity(scanner.barcodeConfidence * 0.5) // Max 50% opacity
                                    .padding(.leading, 24)

                                Spacer()
                            }
                            .offset(y: -100) // Align with center of scanning frame

                            Spacer()
                        }
                        .animation(.easeInOut(duration: 0.2), value: scanner.barcodeConfidence)
                    }

                    // Batch location badge (top center)
                    if let batchLocation = rapidState?.batchLocation {
                        VStack {
                            BatchLocationBadge(
                                locationName: batchLocation.locationName,
                                cardCount: rapidState?.currentBatchCount ?? 0,
                                onChangeLocation: {
                                    // Allow changing location mid-batch
                                    rapidState?.clearBatchLocation()
                                    dismiss()
                                }
                            )
                            .padding(.top, 100)

                            Spacer()
                        }
                    }
                    
                    // Thumbnail stack button in bottom corner
                    if !capturedImages.isEmpty {
                        GeometryReader { geometry in
                            VStack {
                                Spacer()
                                
                                HStack {
                                    Spacer()
                                    
                                    Button(action: {
                                        showingCapturedImages = true
                                    }) {
                                        ZStack(alignment: .topTrailing) {
                                            // Show the most recent image as thumbnail
                                            if let latestImage = capturedImages.last {
                                                Image(uiImage: latestImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                            
                                            // Badge showing count
                                            if capturedImages.count > 1 {
                                                Text("\(capturedImages.count)")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .frame(width: 20, height: 20)
                                                    .background(Color.appPrimary)
                                                    .clipShape(Circle())
                                                    .offset(x: 8, y: -8)
                                            }
                                        }
                                        .frame(width: 60, height: 60)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                    .padding(.trailing, 16)
                                    .padding(.bottom, geometry.safeAreaInsets.bottom + 20)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    
                    // Capture preview overlay
                    if showingCapturePreview, let previewImage = capturedPreviewImage {
                        ZStack {
                            Color.black.opacity(0.9)
                                .ignoresSafeArea()

                            VStack {
                                // Close button
                                HStack {
                                    Spacer()
                                    Button(action: {
                                        withAnimation {
                                            showingCapturePreview = false
                                            previewImageRotation = 0
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding()
                                    }
                                }

                                // Image with rotation
                                Image(uiImage: previewImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .rotationEffect(.degrees(previewImageRotation))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(40)

                                // Rotation controls
                                HStack(spacing: 40) {
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            previewImageRotation -= 90
                                        }
                                    }) {
                                        Image(systemName: "rotate.left")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .frame(width: 50, height: 50)
                                            .background(Color.white.opacity(0.2))
                                            .clipShape(Circle())
                                    }

                                    Button(action: {
                                        withAnimation(.spring()) {
                                            previewImageRotation += 90
                                        }
                                    }) {
                                        Image(systemName: "rotate.right")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .frame(width: 50, height: 50)
                                            .background(Color.white.opacity(0.2))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.bottom, 40)
                            }
                        }
                        .transition(.opacity)
                        .zIndex(100)
                    }
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
                // Ensure we reset and start scanning when view appears
                scanner.resetScanning()
            }
            .onDisappear {
                scanner.stopScanning()
            }
            .onChange(of: scanner.scannedCode) { oldValue, newValue in
                if let code = newValue, let type = scanner.detectedType {
                    // Check if we should use rapid mode
                    if rapidState?.mode == .rapid || rapidState?.mode == .batch {
                        handleRapidScan(code, type: type)
                    } else {
                        handleScannedCode(code, type: type)
                    }
                }
            }
            .autoSaveToast(
                isPresented: Binding(
                    get: { rapidState?.showAutoSaveToast ?? false },
                    set: { rapidState?.showAutoSaveToast = $0 }
                ),
                cardName: rapidState?.toastCard?.name ?? "",
                confidence: rapidState?.toastCard?.confidence ?? 0,
                onEdit: {
                    // Navigate to edit the card
                    if let cardId = rapidState?.toastCard?.id {
                        showEditSheet(for: cardId)
                    }
                },
                onUndo: {
                    // Undo the last save
                    rapidState?.undoLastScan(modelContext: modelContext)
                }
            )
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
            .sheet(isPresented: $showingSaveSheet) {
                if let code = scannedCode, let type = detectedBarcodeType {
                    ScannedCardReviewView(
                        barcodeNumber: code,
                        barcodeType: type,
                        capturedImage: scanner.bestCapturedImage,
                        barcodeBoundingBox: scanner.bestBarcodeBoundingBox,
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
            .sheet(isPresented: $showingCapturedImages) {
                CapturedImagesGalleryView(
                    images: capturedImages,
                    onSelect: { image in
                        // Use selected image for barcode detection
                        useCapturedImage(image)
                        showingCapturedImages = false
                    },
                    onDelete: { index in
                        capturedImages.remove(at: index)
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private func handleScannedCode(_ code: String, type: BarcodeType) {
        scannedCode = code
        detectedBarcodeType = type
        showingSaveSheet = true
    }

    // MARK: - Rapid Scan Handler

    /// Handle barcode detection in rapid/batch mode
    private func handleRapidScan(_ code: String, type: BarcodeType) {
        guard !isProcessingRapidScan else { return }

        isProcessingRapidScan = true
        rapidScanConfidence = 0.0

        Task {
            do {
                // Get the best captured image
                guard let capturedImage = scanner.bestCapturedImage else {
                    showReviewScreen(code, type: type)
                    return
                }

                // 1. Perform OCR
                let ocrResult = try await VisionOCRService.shared.analyzeCardImage(capturedImage)

                // Update confidence during processing
                await MainActor.run {
                    rapidScanConfidence = ocrResult.confidence
                }

                // 2. Parse data
                let parsedData = await CardDataParser.shared.parseFromVisionOCR(
                    ocrResult,
                    userLocation: nil
                )

                // 3. Evaluate save decision
                let decision = await RapidSaveService.shared.evaluateSave(
                    ocrResult: ocrResult,
                    parsedData: parsedData,
                    batchContext: rapidState?.batchLocation,
                    threshold: rapidState?.autoSaveThreshold ?? 0.85
                )

                await MainActor.run {
                    rapidScanConfidence = decision.confidence
                }

                // 4. Route based on confidence
                if decision.shouldAutoSave {
                    // AUTO-SAVE PATH
                    await performInstantSave(
                        barcodePayload: code,
                        barcodeType: type,
                        cardName: decision.suggestedName,
                        capturedImage: capturedImage,
                        boundingBox: scanner.bestBarcodeBoundingBox,
                        parsedData: parsedData,
                        ocrResult: ocrResult,
                        confidence: decision.confidence
                    )
                } else {
                    // LOW CONFIDENCE - Fall back to manual review
                    showReviewScreen(code, type: type)
                }

            } catch {
                print("Error in rapid scan: \(error)")
                // Fall back to manual review on error
                showReviewScreen(code, type: type)
            }

            await MainActor.run {
                isProcessingRapidScan = false
            }
        }
    }

    /// Show review screen for manual editing (fallback for low confidence)
    @MainActor
    private func showReviewScreen(_ code: String, type: BarcodeType) {
        scannedCode = code
        detectedBarcodeType = type
        showingSaveSheet = true
        rapidScanConfidence = 0.0
    }

    /// Show edit sheet for a saved card
    private func showEditSheet(for cardId: String) {
        let descriptor = FetchDescriptor<CardModel>(
            predicate: #Predicate<CardModel> { card in
                card.id == cardId
            }
        )

        if let cards = try? modelContext.fetch(descriptor),
           let card = cards.first {
            savedCardToEdit = card
            showingEditSheet = true
        }
    }

    // MARK: - Instant Save

    /// Perform instant save for high-confidence scans
    private func performInstantSave(
        barcodePayload: String,
        barcodeType: BarcodeType,
        cardName: String,
        capturedImage: UIImage,
        boundingBox: CGRect?,
        parsedData: ParsedCardData,
        ocrResult: VisionOCRService.OCRResult,
        confidence: Float
    ) async {
        do {
            let keychainService = KeychainService()

            // Get or create master key
            var masterKey = try keychainService.getMasterKey()
            if masterKey == nil {
                masterKey = try keychainService.generateAndStoreMasterKey()
            }

            guard let key = masterKey else {
                throw NSError(domain: "CardOnCue", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to get encryption key"
                ])
            }

            // Extract OCR segments
            let segments = OCRSegmentDetector.shared.detectSegments(from: ocrResult, parsedData: parsedData)

            let ocrData = OCRData(
                fullText: ocrResult.allText,
                segments: segments,
                confidence: ocrResult.confidence
            )

            // Determine icon (use batch location icon if available)
            var cardIcon: CardIcon
            if let batchIcon = rapidState?.batchLocation?.icon {
                cardIcon = batchIcon
            } else {
                // Auto-assign SF Symbol
                let iconName = await CardIconService.shared.assignIconForCard(
                    name: cardName,
                    locationName: parsedData.suggestedLocations.first?.name
                )
                cardIcon = CardIcon.sfSymbol(iconName)
            }

            // Get location data (from batch context or parsed data)
            let locationName: String?
            let latitude: Double?
            let longitude: Double?
            let address: String?

            if let batchLoc = rapidState?.batchLocation {
                locationName = batchLoc.locationName
                latitude = batchLoc.latitude
                longitude = batchLoc.longitude
                address = batchLoc.address
            } else if let firstLocation = parsedData.suggestedLocations.first {
                locationName = firstLocation.name
                latitude = firstLocation.coordinate?.latitude
                longitude = firstLocation.coordinate?.longitude
                address = firstLocation.address
            } else {
                locationName = nil
                latitude = nil
                longitude = nil
                address = nil
            }

            // Create card
            let card = try CardModel.createWithEncryptedPayload(
                userId: AppUser.id,
                name: cardName,
                barcodeType: barcodeType,
                payload: barcodePayload,
                masterKey: key,
                tags: [],
                validTo: nil,
                oneTime: false,
                iconName: cardIcon.type == .sfSymbol ? cardIcon.value : "creditcard.fill"
            )

            // Set additional fields
            if let personName = parsedData.personName {
                card.metadata["personName"] = personName
            }
            card.locationName = locationName
            card.locationLatitude = latitude
            card.locationLongitude = longitude
            if let addr = address {
                card.metadata["locationAddress"] = addr
            }

            // Store OCR data as JSON
            if let ocrJSON = try? JSONEncoder().encode(ocrData) {
                card.ocrDataJSON = String(data: ocrJSON, encoding: .utf8)
            }

            // Store icon data as JSON
            if let iconJSON = try? JSONEncoder().encode(cardIcon) {
                card.iconDataJSON = String(data: iconJSON, encoding: .utf8)
            }

            // Save images
            let imageStorage = CardImageStorageService.shared
            if let originalURL = try? imageStorage.saveImage(capturedImage, cardId: card.id, isProcessed: false) {
                card.originalImageURL = originalURL.lastPathComponent
            }

            // Save card to SwiftData
            await MainActor.run {
                modelContext.insert(card)
                PersistenceHelper.save(modelContext, label: "BarcodeScannerView.saveCard")

                // Add to recent scans
                let autoSavedCard = AutoSavedCard(
                    id: card.id,
                    name: cardName,
                    timestamp: Date(),
                    confidence: confidence
                )
                rapidState?.addRecentScan(autoSavedCard)

                // Success feedback
                UINotificationFeedbackGenerator().notificationOccurred(.success)

                // If in batch mode, reset scanner for next card
                if rapidState?.mode == .batch {
                    scanner.resetScanning()
                    rapidScanConfidence = 0.0
                } else {
                    // In rapid mode (not batch), close scanner after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            }

        } catch {
            print("Error saving card: \(error)")
            // Show error and fall back to review screen
            await MainActor.run {
                showingSaveSheet = true
            }
        }
    }

    private func captureImage() {
        guard let image = scanner.captureCurrentFrame() else { return }

        // Add to captured images
        capturedImages.append(image)

        // Show preview (stays open until user closes it)
        capturedPreviewImage = image
        previewImageRotation = 0  // Reset rotation for new image
        showingCapturePreview = true

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func useCapturedImage(_ image: UIImage) {
        // Process the selected image for barcode detection
        Task {
            let barcodeData = await BarcodeQualityService.shared.detectBestBarcode(in: image)
            
            if let barcode = barcodeData {
                await MainActor.run {
                    scannedCode = barcode.payload
                    detectedBarcodeType = barcode.barcodeType
                    scanner.bestCapturedImage = image
                    showingSaveSheet = true
                }
            }
        }
    }
}

// MARK: - Scanner View Model

#if !os(visionOS)
class BarcodeScannerViewModel: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var detectedType: BarcodeType?
    @Published var isScanning = false
    @Published var scanSuccess = false
    @Published var isFlashOn = false
    @Published var hasFlash = false
    @Published var barcodeDetected = false  // New: indicates barcode found, awaiting user confirmation
    @Published var bestCapturedImage: UIImage?  // New: best quality frame captured
    @Published var barcodeConfidence: Double = 0.0  // Current barcode detection confidence (0.0 to 1.0)
    @Published var bestBarcodeBoundingBox: CGRect?  // Bounding box of detected barcode for auto-crop fallback

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
    // These are accessed from nonisolated delegate methods, so marked as nonisolated(unsafe)
    nonisolated(unsafe) private var frameCounter = 0
    nonisolated(unsafe) private var frameSkipCount = 3  // Initial value, will be adjusted dynamically
    private var lastFrameProcessTime: Date?
    nonisolated(unsafe) private var averageProcessingTime: TimeInterval = 0.0
    private let maxProcessingTime: TimeInterval = 0.1  // 100ms budget per frame
    
    // Flag to check if scanning is complete (accessed from nonisolated context)
    nonisolated(unsafe) private var isScanComplete = false

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
        // Reset scanning state first
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Reset all state flags to ensure fresh start
            self.isScanComplete = false
            self.scannedCode = nil
            self.detectedType = nil
            self.scanSuccess = false
            self.barcodeDetected = false
            self.bestCapturedImage = nil
            self.bestBarcodeBoundingBox = nil
            self.barcodeFirstDetectedAt = nil
            self.detectedBarcodePayload = nil
            self.frameBuffer.removeAll()
            self.autoSelectTimer?.invalidate()
            self.autoSelectTimer = nil
            self.barcodeConfidence = 0.0
            self.isScanning = true
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stopScanning() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isScanning = false
            // Reset completion flag so scanner can be restarted
            self.isScanComplete = false
        }
    }

    func resetScanning() {
        scannedCode = nil
        detectedType = nil
        scanSuccess = false
        barcodeDetected = false
        bestCapturedImage = nil
        bestBarcodeBoundingBox = nil
        barcodeFirstDetectedAt = nil
        detectedBarcodePayload = nil
        frameBuffer.removeAll()
        autoSelectTimer?.invalidate()
        autoSelectTimer = nil
        isScanComplete = false
        barcodeConfidence = 0.0
        startScanning()
    }

    // Called when user confirms they want to use the detected barcode
    func confirmBarcodeSelection() {
        guard let payload = detectedBarcodePayload else { return }

        // Find all frames with matching barcode payload
        let matchingFrames = frameBuffer.filter { frame in
            frame.barcodeData?.payload == payload
        }

        // If we have matching frames, select the one with highest quality
        if let bestFrame = matchingFrames.max(by: { $0.qualityScore < $1.qualityScore }) {
            bestCapturedImage = bestFrame.image
            bestBarcodeBoundingBox = bestFrame.barcodeData?.boundingBox
            scannedCode = payload
            detectedType = bestFrame.barcodeData?.barcodeType
            scanSuccess = true
            isScanComplete = true
            stopScanning()
        } else {
            // Fallback: use the most recent frame even without barcode data
            // This handles cases where Vision framework hasn't detected the barcode yet
            // but AVFoundation metadata output has
            if let recentFrame = frameBuffer.last {
                bestCapturedImage = recentFrame.image
                bestBarcodeBoundingBox = recentFrame.barcodeData?.boundingBox
                scannedCode = payload
                detectedType = detectedType  // Use the type from metadata detection
                scanSuccess = true
                isScanComplete = true
                stopScanning()
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
    
    /// Capture the current frame from the camera
    func captureCurrentFrame() -> UIImage? {
        // Get the best frame from the buffer, or the most recent one
        if let bestFrame = frameBuffer.max(by: { ($0.qualityScore) < ($1.qualityScore) }) {
            return bestFrame.image
        }
        // Fallback to most recent frame
        return frameBuffer.last?.image
    }

    /// Get the correct image orientation based on device orientation (nonisolated)
    nonisolated private func getImageOrientationNonisolated() -> UIImage.Orientation {
        // Default to right orientation (portrait) since we can't access UIDevice from nonisolated context
        // This is safe as the app is portrait-only
        return .right
    }
}

// MARK: - Video Data Delegate

extension BarcodeScannerViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Don't process if we've already confirmed a selection
        guard !isScanComplete else { return }
        
        // Adaptive frame throttling: only process every Nth frame
        frameCounter += 1
        guard frameCounter % (frameSkipCount + 1) == 0 else { return }
        
        // Convert sample buffer to UIImage
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Create UIImage from pixel buffer (nonisolated operation)
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }

        // Get correct orientation based on device orientation (nonisolated access)
        let orientation = self.getImageOrientationNonisolated()
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
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
            
            // Add to buffer and adjust throttling on main actor
            await MainActor.run {
                // Double-check we haven't completed scanning
                guard !self.isScanComplete else { return }
                self.addToFrameBuffer(frame)
                self.adjustThrottlingBasedOnPerformance(processingTime)
                
                // Update confidence based on latest frame
                if let barcodeData = frame.barcodeData {
                    // Use exponential moving average for smooth confidence updates
                    let alpha = 0.3
                    self.barcodeConfidence = alpha * barcodeData.confidence + (1 - alpha) * self.barcodeConfidence
                } else {
                    // Decay confidence when no barcode detected
                    self.barcodeConfidence *= 0.9
                    if self.barcodeConfidence < 0.05 {
                        self.barcodeConfidence = 0.0
                    }
                }
            }
        }
    }
}

// MARK: - Metadata Delegate

extension BarcodeScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        // Ignore if already completed
        guard !isScanComplete else { return }

        // Get first barcode
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = metadataObject.stringValue else {
            return
        }

        // Map AVMetadataObject type to BarcodeType
        let barcodeType = mapToBarcodeType(metadataObject.type)

        // Update state to show Continue button (but keep scanning!)
        // Access MainActor-isolated properties from MainActor
        Task { @MainActor in
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Double-check we haven't completed scanning
            guard !self.barcodeDetected && self.scannedCode == nil else { return }
            
            self.barcodeDetected = true
            self.detectedBarcodePayload = code
            self.detectedType = barcodeType
            self.barcodeFirstDetectedAt = Date()

            // Start auto-select timer
            // Use instant confirmation (0.1s) for rapid/batch mode to minimize delays
            // Use 1.5s for standard mode to give user time to see the Continue button
            let timerInterval: TimeInterval = 0.1  // Instant for all modes now
            self.autoSelectTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.confirmBarcodeSelection()
                }
            }
        }
    }

    nonisolated private func mapToBarcodeType(_ type: AVMetadataObject.ObjectType) -> BarcodeType {
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
#endif // !os(visionOS)

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

// MARK: - Captured Images Gallery View

struct CapturedImagesGalleryView: View {
    @Environment(\.dismiss) var dismiss
    let images: [UIImage]
    let onSelect: (UIImage) -> Void
    let onDelete: (Int) -> Void
    
    @State private var selectedIndex: Int?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        Button(action: {
                            selectedIndex = index
                            onSelect(image)
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                // Delete button
                                Button(action: {
                                    onDelete(index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                                .offset(x: 8, y: -8)
                            }
                            .frame(width: 100, height: 100)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Captured Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    BarcodeScannerView()
        .modelContainer(for: CardModel.self, inMemory: true)
}
#endif // !os(visionOS)
