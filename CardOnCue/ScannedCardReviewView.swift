import SwiftUI
import SwiftData

struct ScannedCardReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let barcodeNumber: String
    let barcodeType: BarcodeType
    let capturedImage: UIImage? // Optional captured card image

    var onSave: () -> Void
    var onRescan: () -> Void

    @State private var cardName: String = ""
    @State private var hasExpiryDate: Bool = false
    @State private var expiryDate: Date = Date().addingTimeInterval(365 * 24 * 60 * 60)
    @State private var isOneTime: Bool = false
    @State private var tags: String = ""

    @State private var isLoading: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    // Image processing state
    @State private var processedImage: ProcessedCardImage?
    @State private var isProcessingImage: Bool = false
    @State private var useProcessedImage: Bool = true
    @State private var showingImagePreview: Bool = false

    private let keychainService = KeychainService()
    private let imageProcessor = CardImageProcessor.shared
    private let imageStorage = CardImageStorageService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Success header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.appGreen.opacity(0.1))
                                    .frame(width: 80, height: 80)

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.appGreen)
                            }

                            Text("Barcode Scanned!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.appBlue)

                            // Barcode info
                            VStack(spacing: 4) {
                                Text(barcodeType.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.appGreen)

                                Text(barcodeNumber)
                                    .font(.caption)
                                    .foregroundColor(.appLightGray)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.top, 16)
                        
                        // Card image preview (if available)
                        if let capturedImage = capturedImage {
                            CardImagePreviewSection(
                                originalImage: capturedImage,
                                processedImage: processedImage,
                                isProcessing: isProcessingImage,
                                useProcessedImage: $useProcessedImage,
                                showingPreview: $showingImagePreview
                            )
                            .padding(.horizontal, 24)
                        }

                        // Form fields
                        VStack(spacing: 20) {
                            // Card Name
                            FormSection(title: "Card Name", icon: "tag.fill") {
                                TextField("e.g., Costco Membership", text: $cardName)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.words)
                            }

                            // Optional: Expiry Date
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: $hasExpiryDate) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.appBlue)
                                            .frame(width: 20)
                                        Text("Has Expiry Date")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.appBlue)
                                    }
                                }
                                .tint(.appPrimary)

                                if hasExpiryDate {
                                    DatePicker(
                                        "Expires On",
                                        selection: $expiryDate,
                                        in: Date()...,
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.compact)
                                    .tint(.appPrimary)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                }
                            }

                            // Optional: One-Time Card
                            Toggle(isOn: $isOneTime) {
                                HStack(spacing: 8) {
                                    Image(systemName: "1.circle")
                                        .foregroundColor(.appBlue)
                                        .frame(width: 20)
                                    Text("One-Time Use Card")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appBlue)
                                }
                            }
                            .tint(.appPrimary)

                            // Optional: Tags
                            FormSection(title: "Tags (Optional)", icon: "tag") {
                                TextField("e.g., Grocery, Membership", text: $tags)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.words)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Action buttons
                        VStack(spacing: 12) {
                            Button(action: saveCard) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.headline)
                                        Text("Save Card")
                                            .font(.headline)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isFormValid ? Color.appPrimary : Color.appLightGray)
                                .cornerRadius(12)
                            }
                            .disabled(!isFormValid || isLoading)

                            Button(action: {
                                onRescan()
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.subheadline)
                                    Text("Scan Again")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.appBlue)
                                .padding(.vertical, 12)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onSave()
                    }
                    .foregroundColor(.appBlue)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Process image when view appears
                if let image = capturedImage {
                    processImage(image)
                }
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        isProcessingImage = true
        
        Task {
            do {
                let result = try await imageProcessor.processCardImage(original: image)
                await MainActor.run {
                    processedImage = result
                    useProcessedImage = result.isProcessed
                    isProcessingImage = false
                }
            } catch {
                // Silently fail - we'll just use the original image
                await MainActor.run {
                    processedImage = ProcessedCardImage(
                        original: image,
                        processed: nil,
                        confidence: 0.0,
                        processingMetadata: nil
                    )
                    useProcessedImage = false
                    isProcessingImage = false
                }
            }
        }
    }

    private var isFormValid: Bool {
        !cardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveCard() {
        isLoading = true

        Task {
            do {
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

                // Parse tags
                let tagArray = tags
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                // Create card with encrypted payload
                let card = try CardModel.createWithEncryptedPayload(
                    userId: "local",
                    name: cardName.trimmingCharacters(in: .whitespacesAndNewlines),
                    barcodeType: barcodeType,
                    payload: barcodeNumber,
                    masterKey: key,
                    tags: tagArray,
                    validTo: hasExpiryDate ? expiryDate : nil,
                    oneTime: isOneTime
                )
                
                // Save images if available
                if let processed = processedImage {
                    // Save original image
                    if let originalURL = try? imageStorage.saveImage(
                        processed.original,
                        cardId: card.id,
                        isProcessed: false
                    ) {
                        card.originalImageURL = originalURL.path
                    }
                    
                    // Save processed image if available
                    if let processedImg = processed.processed,
                       let processedURL = try? imageStorage.saveImage(
                        processedImg,
                        cardId: card.id,
                        isProcessed: true
                    ) {
                        card.processedImageURL = processedURL.path
                        card.processingConfidence = Double(processed.confidence)
                        card.useProcessedImage = useProcessedImage && processed.isProcessed
                        
                        // Save processing metadata
                        if let metadata = processed.processingMetadata {
                            card.setProcessingMetadata(metadata)
                        }
                    } else {
                        // No processed image, use original
                        card.useProcessedImage = false
                    }
                }

                // Save to SwiftData
                await MainActor.run {
                    modelContext.insert(card)
                    try? modelContext.save()
                }

                // Success! Dismiss and call completion
                await MainActor.run {
                    isLoading = false
                    dismiss()
                    onSave()
                }

            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Card Image Preview Section

struct CardImagePreviewSection: View {
    let originalImage: UIImage
    let processedImage: ProcessedCardImage?
    let isProcessing: Bool
    @Binding var useProcessedImage: Bool
    @Binding var showingPreview: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "photo")
                    .foregroundColor(.appBlue)
                    .frame(width: 20)
                Text("Card Image")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appBlue)
                Spacer()
                
                if let processed = processedImage, processed.isProcessed {
                    Button(action: { showingPreview = true }) {
                        Text("Preview")
                            .font(.caption)
                            .foregroundColor(.appBlue)
                    }
                }
            }
            
            // Image preview
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(height: 200)
                
                if isProcessing {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Processing image...")
                            .font(.caption)
                            .foregroundColor(.appLightGray)
                    }
                } else {
                    let displayImage = useProcessedImage && processedImage?.processed != nil
                        ? processedImage?.processed
                        : originalImage
                    
                    if let image = displayImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                    }
                }
            }
            
            // Toggle between original and processed
            if let processed = processedImage, processed.isProcessed {
                Toggle(isOn: $useProcessedImage) {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.appBlue)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use processed image")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.appBlue)
                            if let confidence = processed.processingMetadata?.detectionConfidence {
                                Text("Confidence: \(Int(confidence * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.appLightGray)
                            }
                        }
                    }
                }
                .tint(.appPrimary)
            }
        }
        .sheet(isPresented: $showingPreview) {
            CardImageComparisonView(
                originalImage: originalImage,
                processedImage: processedImage,
                useProcessedImage: $useProcessedImage
            )
        }
    }
}

// MARK: - Card Image Comparison View

struct CardImageComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    let originalImage: UIImage
    let processedImage: ProcessedCardImage?
    @Binding var useProcessedImage: Bool
    
    @State private var showingOriginal = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Toggle button
                        Picker("Image Version", selection: $showingOriginal) {
                            Text("Processed").tag(false)
                            Text("Original").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        
                        // Image display
                        let displayImage = showingOriginal
                            ? originalImage
                            : (processedImage?.processed ?? originalImage)
                        
                        Image(uiImage: displayImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                        
                        // Info
                        if let processed = processedImage, !showingOriginal {
                            VStack(alignment: .leading, spacing: 8) {
                                if let metadata = processed.processingMetadata {
                                    InfoRow(label: "Confidence", value: "\(Int(metadata.detectionConfidence * 100))%")
                                    InfoRow(label: "Processing Time", value: "\(metadata.processingTimeMs)ms")
                                    InfoRow(label: "Original Size", value: "\(metadata.originalDimensions.width)×\(metadata.originalDimensions.height)")
                                    if let processedDims = metadata.processedDimensions {
                                        InfoRow(label: "Processed Size", value: "\(processedDims.width)×\(processedDims.height)")
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 24)
                        }
                    }
                }
            }
            .navigationTitle("Card Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appBlue)
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.appLightGray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.appBlue)
        }
    }
}

#Preview {
    ScannedCardReviewView(
        barcodeNumber: "1234567890123",
        barcodeType: .qr,
        capturedImage: nil,
        onSave: {},
        onRescan: {}
    )
    .modelContainer(for: CardModel.self, inMemory: true)
}
