import SwiftUI
import UIKit
import CoreLocation

enum SmartScanStep {
    case captureCard
    case processing
    case scanBarcode
    case preview
}

struct SmartCardScannerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storageService: StorageService

    @State private var currentStep: SmartScanStep = .captureCard
    @State private var cardFrontImage: UIImage?
    @State private var barcodeImage: UIImage?
    @State private var parsedData: ParsedCardData?
    @State private var selectedBarcode: DetectedBarcodeData?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showTip = false
    @State private var cardSignature: CardSignature?
    @State private var matchedTemplate: CardTemplate?

    @StateObject private var locationManager = SimpleLocationManager()

    var body: some View {
        NavigationView {
            ZStack {
                switch currentStep {
                case .captureCard:
                    cardCaptureView
                case .processing:
                    processingView
                case .scanBarcode:
                    barcodeCaptureView
                case .preview:
                    if let parsed = parsedData {
                        CardDataPreviewView(
                            cardImage: cardFrontImage,
                            parsedData: parsed,
                            selectedBarcode: selectedBarcode,
                            onConfirm: { updatedData, barcode in
                                saveCard(data: updatedData, barcode: barcode)
                            },
                            onCancel: {
                                dismiss()
                            }
                        )
                    }
                }
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    private var cardCaptureView: some View {
        CameraCaptureView(mode: .frontCardImage) { image in
            cardFrontImage = image
            Task {
                await processCardImage(image)
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)

            VStack(spacing: 8) {
                Text("Analyzing card...")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text("Reading text and detecting barcode")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
            }

            if let parsed = parsedData, let cardName = parsed.cardName {
                VStack(spacing: 4) {
                    Text("Found: \(cardName)")
                        .font(.subheadline)
                        .foregroundColor(.appPrimary)

                    if selectedBarcode != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Barcode detected")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var barcodeCaptureView: some View {
        ZStack(alignment: .top) {
            CameraCaptureView(mode: .barcodeImage) { image in
                barcodeImage = image
                Task {
                    await detectBarcode(in: image)
                }
            }

            // Educational tip banner
            if showTip {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pro Tip")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Include the barcode in your first photo for instant scanning!")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            withAnimation {
                                showTip = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            // Show tip for 5 seconds, then auto-dismiss
            showTip = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    showTip = false
                }
            }
        }
    }

    private func processCardImage(_ image: UIImage) async {
        currentStep = .processing

        // Try to extract text first
        guard let extractedText = await CardOCRService.shared.extractText(from: image) else {
            await MainActor.run {
                errorMessage = "Could not read text from card. Please try again with better lighting."
                showError = true
                currentStep = .captureCard
            }
            return
        }

        // Compute card signature for template matching
        let signature = CardSignatureService.shared.computeSignature(
            image: image,
            extractedText: extractedText
        )

        await MainActor.run {
            self.cardSignature = signature
        }

        // Check for matching templates from backend
        let templates = await CardSignatureService.shared.findMatchingTemplates(signature: signature)

        // Also try to detect barcode in the same image
        let barcodes = await BarcodeQualityService.shared.detectBarcodes(in: image)

        let userLocation = await locationManager.requestLocation()
        var parsed = await CardDataParser.shared.parseCard(
            extractedText: extractedText,
            userLocation: userLocation
        )

        // If we have a matching template, use it to pre-fill location data
        if let template = templates.first {
            await MainActor.run {
                self.matchedTemplate = template
            }

            // Pre-fill card name from template if OCR didn't detect it
            if parsed.cardName == nil || parsed.cardName?.isEmpty == true {
                parsed.cardName = template.cardName
            }

            // Pre-fill location from template
            if let locationName = template.locationName,
               let locationLat = template.locationLat,
               let locationLng = template.locationLng {
                let templateLocation = LocationSuggestion(
                    name: locationName,
                    address: template.locationAddress ?? "",
                    coordinate: CLLocationCoordinate2D(latitude: locationLat, longitude: locationLng),
                    distance: userLocation?.distance(from: CLLocation(latitude: locationLat, longitude: locationLng))
                )

                // Insert template location at the beginning
                parsed.suggestedLocations.insert(templateLocation, at: 0)
            }
        }

        await MainActor.run {
            self.parsedData = parsed

            // If we found a barcode in the card image, use it and skip the barcode scan step
            if let detectedBarcode = barcodes.first {
                self.selectedBarcode = detectedBarcode

                if parsed.cardName != nil {
                    // We have both card info and barcode - go straight to preview
                    currentStep = .preview
                } else {
                    errorMessage = "Could not identify card name. Please try again."
                    showError = true
                    currentStep = .captureCard
                }
            } else {
                // No barcode found in image, need separate barcode scan
                if parsed.cardName != nil {
                    currentStep = .scanBarcode
                } else {
                    errorMessage = "Could not identify card. Please try again or add manually."
                    showError = true
                    currentStep = .captureCard
                }
            }
        }
    }

    private func detectBarcode(in image: UIImage) async {
        currentStep = .processing

        let barcodes = await BarcodeQualityService.shared.detectBarcodes(in: image)

        await MainActor.run {
            if let firstBarcode = barcodes.first {
                selectedBarcode = firstBarcode
                currentStep = .preview
            } else {
                // No error alert - just go back to barcode scan for retry
                // User can try again without interruption
                currentStep = .scanBarcode
            }
        }
    }

    private func saveCard(data: ParsedCardData, barcode: DetectedBarcodeData?) {
        guard let barcode = barcode else {
            errorMessage = "Barcode is required"
            showError = true
            return
        }

        guard let userId = storageService.userId else {
            errorMessage = "User not authenticated"
            showError = true
            return
        }

        let card = Card(
            userId: userId,
            name: data.cardName ?? "Card",
            barcodeType: barcode.barcodeType,
            payload: barcode.payload,
            cardType: data.cardType ?? .membership,
            frontCardImage: cardFrontImage.flatMap { img in
                if let filePath = ImageStorageService.shared.saveImage(img, for: UUID().uuidString, type: .frontCard) {
                    return CardFrontImage(localFilePath: filePath)
                }
                return nil
            },
            personName: data.personName,
            locationName: data.suggestedLocations.first?.name
        )

        storageService.addCard(card)

        // Submit template to backend for future users (async, non-blocking)
        if let signature = cardSignature {
            Task {
                await CardSignatureService.shared.submitTemplate(
                    signature: signature,
                    cardName: data.cardName ?? "Card",
                    cardType: data.cardType?.rawValue,
                    locationName: data.suggestedLocations.first?.name,
                    locationAddress: data.suggestedLocations.first?.address,
                    locationLat: data.suggestedLocations.first?.coordinate?.latitude,
                    locationLng: data.suggestedLocations.first?.coordinate?.longitude
                )
            }
        }

        dismiss()
    }
}

class SimpleLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation() async -> CLLocation? {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            default:
                continuation.resume(returning: nil)
                self.continuation = nil
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        continuation?.resume(returning: locations.first)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

#Preview {
    SmartCardScannerView()
        .environmentObject(StorageService.shared)
}
