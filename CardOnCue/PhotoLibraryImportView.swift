import SwiftUI
import PhotosUI
import SwiftData

struct PhotoLibraryImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isInAddCardFlow) private var isInAddCardFlow

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isLoadingImage = false
    @State private var isProcessing = false
    @State private var scannedCode: String?
    @State private var detectedBarcodeType: BarcodeType?
    @State private var capturedImage: UIImage?
    @State private var showingSaveSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingManualEntry = false
    @State private var showPhotoPicker = false
    @State private var hasAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    if isProcessing {
                        // Processing state
                        VStack(spacing: 24) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.appPrimary)

                            Text("Analyzing image for barcodes...")
                                .font(.headline)
                                .foregroundColor(.appBlue)
                        }
                    } else if let selectedImage = selectedImage {
                        // Selected image preview state
                        VStack(spacing: 24) {
                            Text("Selected Image")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.appBlue)

                            // Image preview
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 400)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                                .padding(.horizontal, 24)

                            // Action buttons
                            VStack(spacing: 12) {
                                Button(action: {
                                    processImage(selectedImage)
                                }) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.headline)
                                        Text("Use This Image")
                                            .font(.headline)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.appPrimary)
                                    .cornerRadius(12)
                                }

                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    HStack {
                                        Image(systemName: "photo.fill")
                                            .font(.subheadline)
                                        Text("Choose Different Photo")
                                            .font(.subheadline)
                                    }
                                    .foregroundColor(.appBlue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    } else {
                        // Initial state - photo picker
                        VStack(spacing: 24) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 80))
                                .foregroundColor(.appBlue)

                            VStack(spacing: 12) {
                                Text("Import from Photo Library")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.appBlue)

                                Text("Select a photo containing a barcode or card")
                                    .font(.subheadline)
                                    .foregroundColor(.appLightGray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }

                            Button(action: {
                                showPhotoPicker = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "photo.fill")
                                        .font(.title3)
                                    Text("Choose Photo")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: 280)
                                .padding(.vertical, 16)
                                .background(Color.appPrimary)
                                .cornerRadius(12)
                            }

                            // Manual entry fallback button
                            Button(action: {
                                showingManualEntry = true
                            }) {
                                Text("Enter Manually Instead")
                                    .font(.subheadline)
                                    .foregroundColor(.appBlue)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.top, isInAddCardFlow
                    ? AddCardFlowMetrics.headerHeight(hasModeSelector: false) + 16
                    : 60)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isInAddCardFlow {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.appBlue)
                    }

                    ToolbarItem(placement: .principal) {
                        Text("Import Photo")
                            .foregroundColor(.appBlue)
                            .fontWeight(.semibold)
                    }
                }
            }
            .toolbar(isInAddCardFlow ? .hidden : .visible, for: .navigationBar)
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
            .onAppear {
                // Auto-show photo picker when view first appears
                if !hasAppeared {
                    hasAppeared = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPhotoPicker = true
                    }
                }
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                if let item = newValue {
                    loadSelectedImage(item)
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                if let code = scannedCode, let type = detectedBarcodeType {
                    ScannedCardReviewView(
                        barcodeNumber: code,
                        barcodeType: type,
                        capturedImage: capturedImage,
                        barcodeBoundingBox: nil, // Will be detected from image
                        onSave: {
                            dismiss()
                        },
                        onRescan: {
                            showingSaveSheet = false
                            resetState()
                        }
                    )
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
            .alert("No Barcode Found", isPresented: $showingError) {
                Button("Try Another Photo", role: .cancel) {
                    resetState()
                }
                Button("Enter Manually") {
                    showingManualEntry = true
                }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func loadSelectedImage(_ item: PhotosPickerItem) {
        isLoadingImage = true

        Task {
            do {
                // Load the image data
                guard let imageData = try await item.loadTransferable(type: Data.self),
                      let loadedImage = UIImage(data: imageData) else {
                    await MainActor.run {
                        isLoadingImage = false
                        errorMessage = "Failed to load the selected image."
                        showingError = true
                    }
                    return
                }

                // Debug: Print orientation
                print("📸 Image orientation: \(loadedImage.imageOrientation.rawValue) - \(loadedImage.imageOrientation)")
                print("📸 Image size: \(loadedImage.size)")
                print("📸 CGImage size: \(loadedImage.cgImage?.width ?? 0) x \(loadedImage.cgImage?.height ?? 0)")

                // DON'T normalize - pass image through unchanged
                let image = loadedImage

                // Store and display the image
                await MainActor.run {
                    selectedImage = image
                    isLoadingImage = false
                }
            } catch {
                await MainActor.run {
                    isLoadingImage = false
                    errorMessage = "An error occurred while loading the image: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    private func processImage(_ image: UIImage) {
        isProcessing = true
        capturedImage = image

        Task {
            // Detect barcode in the image
            let barcodeData = await BarcodeQualityService.shared.detectBestBarcode(in: image)

            await MainActor.run {
                isProcessing = false

                if let barcode = barcodeData {
                    // Success! We found a barcode
                    scannedCode = barcode.payload
                    detectedBarcodeType = barcode.barcodeType

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    // Show save sheet
                    showingSaveSheet = true
                } else {
                    // No barcode found
                    errorMessage = "We couldn't detect a barcode in this image. Please try another photo or enter the card details manually."
                    showingError = true
                }
            }
        }
    }

    private func resetState() {
        selectedItem = nil
        selectedImage = nil
        scannedCode = nil
        detectedBarcodeType = nil
        capturedImage = nil
        isProcessing = false
        isLoadingImage = false
    }
}

#Preview {
    PhotoLibraryImportView()
        .modelContainer(for: CardModel.self, inMemory: true)
}

// MARK: - UIImage Orientation Fix
extension UIImage {
    /// Normalize image orientation by redrawing pixels in correct orientation
    /// This ensures the actual pixel data matches the expected upright orientation
    func normalized() -> UIImage {
        guard let cgImage = cgImage else {
            return self
        }

        let width = size.width
        let height = size.height

        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return self
        }

        // Flip the context vertically to match UIKit coordinate system
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1.0, y: -1.0)

        // Draw the CGImage
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Create new image from context
        guard let newCGImage = context.makeImage() else {
            return self
        }

        return UIImage(cgImage: newCGImage, scale: scale, orientation: .up)
    }
}
