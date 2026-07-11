import SwiftUI
import SwiftData

struct ScannedCardReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.apiClient) private var apiClient

    let barcodeNumber: String
    let barcodeType: BarcodeType
    let capturedImage: UIImage? // Optional captured card image
    let barcodeBoundingBox: CGRect? // Optional barcode region from detection
    var reviewProgressLabel: String? = nil
    var dismissesOnSave: Bool = true

    var onSave: () -> Void
    var onRescan: () -> Void

    @State private var cardName: String = ""
    @State private var hasExpiryDate: Bool = false
    @State private var expiryDate: Date = Date().addingTimeInterval(365 * 24 * 60 * 60)
    @State private var isOneTime: Bool = false
    @State private var tags: String = ""

    // New fields for person name and location
    @State private var personName: String = ""
    @State private var locationName: String = ""
    @State private var locationLatitude: Double? = nil
    @State private var locationLongitude: Double? = nil
    @State private var locationAddress: String? = nil
    @State private var isPersonNameAutoPopulated: Bool = false
    @State private var isLocationAutoPopulated: Bool = false

    @State private var isLoading: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""

    // Image processing state
    @State private var processedImage: ProcessedCardImage?
    @State private var isProcessingImage: Bool = false
    @State private var useProcessedImage: Bool = true
    @State private var showingImagePreview: Bool = false

    // OCR state
    @State private var isPerformingOCR: Bool = false
    @State private var parsedCardData: ParsedCardData?

    // Icon extraction state
    @State private var showingIconCrop: Bool = false
    @State private var extractedIcon: CardIcon?

    // Barcode rendering state
    @State private var barcodeImage: UIImage?

    // Contact info state
    @State private var phoneNumber: String = ""
    @State private var emailAddress: String = ""
    @State private var websiteURL: String = ""
    @State private var isPhoneAutoPopulated = false
    @State private var isEmailAutoPopulated = false
    @State private var isWebsiteAutoPopulated = false

    // PIN and card type state
    @State private var pinCode: String = ""
    @State private var cardType: String = ""
    @State private var isPinAutoPopulated = false
    @State private var isCardTypeAutoPopulated = false

    // Template matching state
    @State private var isMatchingTemplate: Bool = false
    @State private var matchedTemplate: CardTemplateMatchResponse.CardTemplate?
    @State private var discoveredBrand: GiftCardBrandResponse?

    private let keychainService = KeychainService()
    private let imageProcessor = CardImageProcessor.shared
    private let imageStorage = CardImageStorageService.shared
    private let barcodeService = BarcodeService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Barcode display header
                        VStack(spacing: 12) {
                            Text("Barcode Scanned!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.appBlue)

                            // Barcode/QR code image
                            if let barcodeImage = barcodeImage {
                                Image(uiImage: barcodeImage)
                                    .resizable()
                                    .interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 300, maxHeight: 150)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .cornerRadius(12)
                            } else {
                                // Loading placeholder
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .frame(height: 150)
                                    ProgressView()
                                }
                                .padding(.horizontal, 24)
                            }

                            // Barcode number
                            Text(barcodeNumber)
                                .font(.caption)
                                .foregroundColor(.appLightGray)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                        .padding(.top, 16)

                        // Form fields
                        VStack(spacing: 20) {
                            // Card Name
                            FormSection(title: "Card Name", icon: "tag.fill") {
                                TextField("e.g., Costco Membership", text: $cardName)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.words)
                            }

                            // Cardholder Name (Optional)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.appBlue)
                                        .frame(width: 20)
                                    Text("Cardholder Name")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appBlue)
                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(.appBlue.opacity(0.6))
                                }

                                TextField("e.g., John Smith", text: $personName)
                                    .textFieldStyle(AutoPopulatedTextFieldStyle(isAutoPopulated: isPersonNameAutoPopulated))
                                    .autocapitalization(.words)
                                    .onChange(of: personName) { oldValue, newValue in
                                        // Clear auto-population flag if user manually edits
                                        if isPersonNameAutoPopulated && newValue != parsedCardData?.personName {
                                            isPersonNameAutoPopulated = false
                                        }
                                    }
                            }

                            // Location (Optional)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.appBlue)
                                        .frame(width: 20)
                                    Text("Location")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appBlue)
                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(.appBlue.opacity(0.6))
                                }

                                LocationSearchField(
                                    locationName: $locationName,
                                    latitude: $locationLatitude,
                                    longitude: $locationLongitude,
                                    address: $locationAddress,
                                    phoneNumber: Binding(
                                        get: { phoneNumber.isEmpty ? nil : phoneNumber },
                                        set: { phoneNumber = $0 ?? "" }
                                    ),
                                    website: Binding(
                                        get: { websiteURL.isEmpty ? nil : websiteURL },
                                        set: { websiteURL = $0 ?? "" }
                                    ),
                                    email: Binding(
                                        get: { emailAddress.isEmpty ? nil : emailAddress },
                                        set: { emailAddress = $0 ?? "" }
                                    ),
                                    isAutoPopulated: isLocationAutoPopulated,
                                    modelContext: modelContext
                                )
                            }

                            // Phone Number (Optional)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "phone.fill")
                                        .foregroundColor(.appBlue)
                                        .frame(width: 20)
                                    Text("Phone Number")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appBlue)
                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(.appBlue.opacity(0.6))
                                    if isPhoneAutoPopulated {
                                        Text("(Auto-filled)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }

                                TextField("Enter phone number", text: $phoneNumber)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.none)
                                    .keyboardType(.phonePad)
                            }
                            .padding(.horizontal, 24)

                            // Email (Optional)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.appBlue)
                                        .frame(width: 20)
                                    Text("Email")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appBlue)
                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(.appBlue.opacity(0.6))
                                    if isEmailAutoPopulated {
                                        Text("(Auto-filled)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }

                                TextField("Enter email address", text: $emailAddress)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                            }
                            .padding(.horizontal, 24)

                            // Website (Optional)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "link")
                                        .foregroundColor(.appBlue)
                                        .frame(width: 20)
                                    Text("Website")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appBlue)
                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(.appBlue.opacity(0.6))
                                    if isWebsiteAutoPopulated {
                                        Text("(Auto-filled)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }

                                TextField("Enter website URL", text: $websiteURL)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.none)
                                    .keyboardType(.URL)
                            }
                            .padding(.horizontal, 24)

                            // PIN (Optional)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.appBlue)
                                        .frame(width: 20)
                                    Text("PIN")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appBlue)
                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(.appBlue.opacity(0.6))
                                    if isPinAutoPopulated {
                                        Text("(Auto-filled)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }

                                TextField("Enter PIN code", text: $pinCode)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.none)
                                    .keyboardType(.numberPad)
                            }
                            .padding(.horizontal, 24)

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
                                    .appLightTextFieldContent()
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
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "tag")
                                        .foregroundColor(.appBlue)
                                        .frame(width: 20)
                                    Text("Tags")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appBlue)
                                    Text("(Optional)")
                                        .font(.caption)
                                        .foregroundColor(.appBlue.opacity(0.6))
                                }

                                TextField("e.g., Grocery, Membership", text: $tags)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.words)
                            }
                        }
                        .padding(.horizontal, 24)

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

                        // Manual icon selection (if image available)
                        if capturedImage != nil {
                            Button(action: {
                                showingIconCrop = true
                            }) {
                                HStack {
                                    Image(systemName: "crop.rotate")
                                        .font(.subheadline)
                                    Text(extractedIcon != nil ? "Change Custom Icon" : "Select Custom Icon from Image")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.appBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.appBlue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 24)
                        }

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

                if let reviewProgressLabel {
                    ToolbarItem(placement: .principal) {
                        Text(reviewProgressLabel)
                            .font(.headline)
                            .foregroundColor(.appBlue)
                    }
                }
            }
            .sheet(isPresented: $showingIconCrop) {
                if let image = capturedImage {
                    IconCropView(
                        image: image,
                        onCrop: { cropRect in
                            Task {
                                if let croppedIcon = await CardIconService.shared.saveIconFromCrop(
                                    image: image,
                                    cropRect: cropRect,
                                    cardName: cardName.isEmpty ? "card" : cardName
                                ) {
                                    await MainActor.run {
                                        extractedIcon = croppedIcon
                                        showingIconCrop = false
                                    }
                                }
                            }
                        },
                        onCancel: {
                            showingIconCrop = false
                        }
                    )
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                // Generate barcode image
                generateBarcodeImage()

                // Process image when view appears
                if let image = capturedImage {
                    processImage(image)
                    performOCR(image)
                    performTemplateMatching(image)
                }
            }
        }
    }
    
    private func generateBarcodeImage() {
        Task {
            do {
                let size = CGSize(width: 600, height: 300)
                let image = try barcodeService.renderBarcode(
                    payload: barcodeNumber,
                    type: barcodeType,
                    size: size
                )
                await MainActor.run {
                    barcodeImage = image
                }
            } catch {
                print("Failed to generate barcode image: \(error)")
                // Fallback: Use the captured camera image
                await MainActor.run {
                    barcodeImage = capturedImage
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

    /// Perform OCR on the card image to extract person name and location
    private func performOCR(_ image: UIImage) {
        isPerformingOCR = true

        Task {
            do {
                // Extract text using VisionOCRService
                let ocrResult = try await VisionOCRService.shared.analyzeCardImage(image)

                // Parse the extracted text
                let parsed = await CardDataParser.shared.parseFromVisionOCR(
                    ocrResult,
                    userLocation: nil // Could pass user location here if available
                )

                // Detect contact information segments
                let segments = OCRSegmentDetector.shared.detectSegments(from: ocrResult, parsedData: parsed)

                await MainActor.run {
                    parsedCardData = parsed

                    // Auto-populate contact information
                    if let phone = segments.first(where: { $0.type == .phoneNumber })?.value {
                        phoneNumber = phone
                        isPhoneAutoPopulated = true
                    }

                    if let email = segments.first(where: { $0.type == .email })?.value {
                        emailAddress = email
                        isEmailAutoPopulated = true
                    }

                    if let website = segments.first(where: { $0.type == .website })?.value {
                        websiteURL = website
                        isWebsiteAutoPopulated = true
                    }

                    // Auto-populate PIN
                    if let pin = segments.first(where: { $0.type == .pin })?.value {
                        pinCode = pin
                        isPinAutoPopulated = true
                    }

                    // Auto-populate card type
                    if let type = segments.first(where: { $0.type == .cardType })?.value {
                        cardType = type
                        isCardTypeAutoPopulated = true
                    }

                    // Auto-populate person name if confidence > 0.7
                    if let name = parsed.personName,
                       let confidence = parsed.personNameConfidence,
                       confidence > 0.7,
                       !name.isEmpty {
                        personName = name
                        isPersonNameAutoPopulated = true
                    }

                    // Auto-populate location from first suggested location
                    if let firstLocation = parsed.suggestedLocations.first {
                        locationName = firstLocation.name
                        isLocationAutoPopulated = true
                    }

                    // Auto-suggest card name if not already set
                    if cardName.isEmpty {
                        // Priority 1: Use extracted brand/merchant name from OCR
                        if let extractedName = ocrResult.cardName, !extractedName.isEmpty {
                            cardName = extractedName
                            // Append card type if available
                            if !cardType.isEmpty {
                                cardName = "\(extractedName) \(cardType)"
                            }
                        }
                        // Priority 2: Build from person name + location
                        else if !personName.isEmpty && !locationName.isEmpty {
                            let firstName = personName.components(separatedBy: " ").first ?? personName
                            cardName = "\(firstName)'s \(locationName)"
                        }
                        // Priority 3: Use location name only
                        else if !locationName.isEmpty {
                            cardName = locationName
                        }
                        // Priority 4: Use person name + "Card" as fallback
                        else if !personName.isEmpty {
                            cardName = "\(personName)'s Card"
                        }
                    }

                    isPerformingOCR = false
                }
            } catch {
                // Silently fail - user can still manually enter information
                await MainActor.run {
                    isPerformingOCR = false
                }
            }
        }
    }

    private func performTemplateMatching(_ image: UIImage) {
        guard let apiClient = apiClient else {
            print("⚠️ API client not available for template matching")
            return
        }

        isMatchingTemplate = true

        Task {
            do {
                // Generate image hash (perceptual hash)
                let imageHash = generateImageHash(from: image)

                // Extract OCR text for signature (we'll wait a bit for OCR to complete)
                try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s for OCR
                let textSignature = parsedCardData?.rawText
                    .joined(separator: " ")
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                    .lowercased()

                // Try template matching
                let matchResponse = try await apiClient.matchCardTemplate(
                    imageHash: imageHash,
                    textSignature: textSignature,
                    limit: 5
                )

                await MainActor.run {
                    if let bestMatch = matchResponse.matches.first, bestMatch.confidenceScore > 0.6 {
                        matchedTemplate = bestMatch

                        // Auto-populate form with template data
                        if cardName.isEmpty {
                            cardName = bestMatch.cardName
                        }

                        if let locName = bestMatch.locationName, !locName.isEmpty {
                            locationName = locName
                            isLocationAutoPopulated = true
                        }

                        if let locAddress = bestMatch.locationAddress {
                            locationAddress = locAddress
                        }

                        if let lat = bestMatch.locationLat, let lng = bestMatch.locationLng {
                            locationLatitude = lat
                            locationLongitude = lng
                        }

                        if let cardTypeFromTemplate = bestMatch.cardType {
                            cardType = cardTypeFromTemplate
                            isCardTypeAutoPopulated = true
                        }

                        print("✅ Matched template: \(bestMatch.cardName) (confidence: \(bestMatch.confidenceScore))")
                    }

                    isMatchingTemplate = false
                }

                // If it looks like a gift card, try brand discovery
                if barcodeType == .code128 || barcodeType == .code39 || barcodeType == .ean13 {
                    tryGiftCardBrandDiscovery()
                }

            } catch {
                print("⚠️ Template matching failed: \(error)")
                await MainActor.run {
                    isMatchingTemplate = false
                }
            }
        }
    }

    private func tryGiftCardBrandDiscovery() {
        guard let apiClient = apiClient else { return }

        Task {
            do {
                let response = try await apiClient.discoverGiftCardBrand(
                    cardName: cardName.isEmpty ? "Gift Card" : cardName,
                    barcode: barcodeNumber,
                    metadata: nil
                )

                await MainActor.run {
                    discoveredBrand = response

                    // Update card name if brand discovered
                    if cardName.isEmpty || cardName == "Gift Card" {
                        cardName = response.brand.name
                    }

                    print("✅ Discovered gift card brand: \(response.brand.name)")
                    print("   Accepted at: \(response.acceptedNetworks.map { $0.networkName }.joined(separator: ", "))")
                }
            } catch {
                // Silently fail - not all cards are gift cards
                print("ℹ️ Gift card discovery did not find a match")
            }
        }
    }

    private func generateImageHash(from image: UIImage) -> String {
        // Simple image hashing - in production, use a proper perceptual hash algorithm
        // For now, we'll create a hash based on resized grayscale image
        guard let cgImage = image.cgImage else { return "" }

        // Resize to 8x8
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContext(size)
        UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
        guard let resized = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return ""
        }
        UIGraphicsEndImageContext()

        // Convert to grayscale and generate hash
        guard let pixelData = resized.cgImage?.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return ""
        }

        var hashString = ""
        for i in 0..<64 {
            let pixelIndex = i * 4 // RGBA
            let gray = data[pixelIndex]
            hashString += String(format: "%02x", gray)
        }

        return hashString
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

                let trimmedCardName = cardName.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedLocationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)

                // Perform OCR first to get website URL and other data
                var websiteUrl: String?
                var ocrDataToSave: OCRData?

                if let imageToAnalyze = processedImage?.processed ?? processedImage?.original {
                    do {
                        let ocrResult = try await VisionOCRService.shared.analyzeCardImage(imageToAnalyze)
                        let segments = OCRSegmentDetector.shared.detectSegments(from: ocrResult, parsedData: parsedCardData)

                        ocrDataToSave = OCRData(
                            fullText: ocrResult.allText,
                            segments: segments,
                            confidence: ocrResult.confidence
                        )

                        // Extract website URL from segments
                        websiteUrl = segments.first { $0.type == .website }?.value
                    } catch {
                        print("Failed to perform OCR during save: \(error)")
                    }
                }

                // Smart icon extraction via unified resolver
                let cachedLocationIcon: CardIcon? = {
                    guard !trimmedLocationName.isEmpty,
                          let cachedLocation = LocationCacheService.shared.findMatches(
                              for: trimmedLocationName,
                              address: locationAddress,
                              userLocation: nil,
                              context: modelContext
                          ).first else {
                        return nil
                    }
                    return cachedLocation.cardIcon
                }()

                let cardIcon = await MembershipIconResolver.shared.resolveIcon(
                    cardName: trimmedCardName,
                    locationName: trimmedLocationName.isEmpty ? nil : trimmedLocationName,
                    websiteUrl: websiteUrl,
                    existingIcon: extractedIcon,
                    cachedLocationIcon: cachedLocationIcon,
                    modelContext: modelContext
                )

                // Create card with encrypted payload
                let card = try CardModel.createWithEncryptedPayload(
                    userId: AppUser.id,
                    name: trimmedCardName,
                    barcodeType: barcodeType,
                    payload: barcodeNumber,
                    masterKey: key,
                    tags: tagArray,
                    validTo: hasExpiryDate ? expiryDate : nil,
                    oneTime: isOneTime,
                    iconName: cardIcon.type == .sfSymbol ? cardIcon.value : "creditcard.fill"
                )

                // Set icon using extracted/fetched icon
                card.setIcon(cardIcon)

                // Save person name if provided
                let trimmedPersonName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedPersonName.isEmpty {
                    card.setMetadata(trimmedPersonName, for: "personName")
                }

                // Save PIN if provided
                let trimmedPinCode = pinCode.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedPinCode.isEmpty {
                    card.setMetadata(trimmedPinCode, for: "pin")
                }

                // Save card type if provided
                let trimmedCardType = cardType.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedCardType.isEmpty {
                    card.setMetadata(trimmedCardType, for: "cardType")
                }

                // Save location data if provided
                if !trimmedLocationName.isEmpty {
                    card.locationName = trimmedLocationName
                    card.locationLatitude = locationLatitude
                    card.locationLongitude = locationLongitude

                    // Save to location cache with business metadata and icon
                    LocationCacheService.shared.saveLocation(
                        name: trimmedLocationName,
                        address: locationAddress,
                        latitude: locationLatitude,
                        longitude: locationLongitude,
                        phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                        website: websiteURL.isEmpty ? nil : websiteURL,
                        email: emailAddress.isEmpty ? nil : emailAddress,
                        icon: cardIcon,  // Save the determined icon to cache
                        context: modelContext
                    )
                }
                
                // ALWAYS persist the original image, independent of whether
                // background processing has finished (or succeeded). The user
                // may tap Save before `processImage` completes, in which case
                // `processedImage` is still nil but `capturedImage` is not.
                let originalToSave = capturedImage ?? processedImage?.original
                if let original = originalToSave {
                    if let originalURL = try? imageStorage.saveImage(
                        original,
                        cardId: card.id,
                        isProcessed: false
                    ) {
                        card.originalImageURL = originalURL.path
                    }
                }

                // Save processed image if available
                if let processed = processedImage,
                   let processedImg = processed.processed,
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

                // Save OCR data if it was extracted (independent of processing)
                if let ocrData = ocrDataToSave {
                    card.setOCRData(ocrData)

                    // Save website URL to metadata
                    if let websiteUrl = websiteUrl {
                        card.setMetadata(websiteUrl, for: "websiteUrl")
                    }
                }

                // Save barcode bounding box for auto-crop fallback
                if let boundingBox = barcodeBoundingBox {
                    // Use provided bounding box from scanner
                    card.barcodeBoundingBox = boundingBox
                } else if let imageToAnalyze = processedImage?.processed ?? originalToSave {
                    // Try to detect barcode bounding box from image
                    if let detected = await BarcodeQualityService.shared.detectBestBarcode(in: imageToAnalyze) {
                        card.barcodeBoundingBox = detected.boundingBox
                    }
                }

                // Save to SwiftData
                await MainActor.run {
                    modelContext.insert(card)
                    PersistenceHelper.save(modelContext, label: "ScannedCardReviewView.saveCard")
                }

                // Success! Dismiss and call completion
                await MainActor.run {
                    isLoading = false
                    if dismissesOnSave {
                        dismiss()
                    }
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
            // Image preview
            Button(action: { showingPreview = true }) {
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
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            
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
        barcodeBoundingBox: nil,
        onSave: {},
        onRescan: {}
    )
    .modelContainer(for: CardModel.self, inMemory: true)
}
