import SwiftUI
import SwiftData
import CryptoKit

struct CardDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let card: CardModel
    
    @State private var brightness: Double = 1.0
    @State private var decryptedPayload: String?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedPersonName: String = ""
    @State private var editedLocationName: String = ""
    @State private var editedNote: String = ""
    @State private var editedIcon: CardIcon? = nil
    @State private var showingRescan = false
    @State private var showingAddPlace = false
    @State private var showingIconSelection = false
    @State private var networks: [Network] = []
    @State private var editedWebsiteUrl: String = ""
    @State private var showingUrlShareAlert = false
    @State private var editedFullText: String = ""
    @State private var editedOCRSegments: [OCRField] = []
    @State private var isExtractingText: Bool = false
    @State private var editedPin: String = ""
    @State private var editedCardType: String = ""

    // Cropped barcode image state
    @State private var croppedBarcodeImage: UIImage? = nil
    @State private var isLoadingCroppedImage: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title at top of content
                titleSection
                
                barcodeSection
                
                cardInfoSection

                // OCR extracted text section (edit mode only)
                if isEditing, let ocrData = card.getOCRData() {
                    extractedTextSection(ocrData: ocrData)
                }

                // Extract text button (if has image but no OCR data)
                if isEditing, card.displayImageURL != nil, card.getOCRData() == nil {
                    extractTextButtonSection
                }

                networksSection

                if !(card.locationName ?? "").isEmpty || isEditing {
                    websiteSection
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        saveChanges()
                    }
                    isEditing.toggle()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Apply to All \(card.brandName) Cards?", isPresented: $showingUrlShareAlert) {
            Button("This Card Only", role: .cancel) { }

            Button("All \(card.brandName) Cards") {
                applyUrlToAllBrandCards()
            }
        } message: {
            Text("Would you like to apply this website URL to all your \(card.brandName) cards?")
        }
        .sheet(isPresented: $showingRescan) {
            BarcodeRescanViewForCardModel(card: card) { updatedPayload, updatedType in
                // Update card with new barcode
                Task {
                    await updateCardBarcode(payload: updatedPayload, type: updatedType)
                }
            }
        }
        .task {
            await decryptPayload()
            await loadNetworks()
        }
        .sheet(isPresented: $showingAddPlace) {
            AddPlaceViewForCardModel(card: card) { placeName in
                editedLocationName = placeName
                // Check database after updating
                Task {
                    await checkDatabaseForPlace(placeName)
                }
            }
        }
        .onAppear {
            editedName = card.name
            editedPersonName = card.metadata["personName"] ?? ""
            editedLocationName = card.locationName ?? ""
            editedNote = card.metadata["note"] ?? ""
            editedIcon = card.getIcon()
            editedWebsiteUrl = card.metadata["websiteUrl"] ?? ""
            editedPin = card.metadata["pin"] ?? ""
            editedCardType = card.metadata["cardType"] ?? ""

            // Load OCR data if available
            if let ocrData = card.getOCRData() {
                editedFullText = ocrData.fullText
                editedOCRSegments = ocrData.segments
            }
        }
        .sheet(isPresented: $showingIconSelection) {
            IconSelectionSheet(card: card, selectedIcon: $editedIcon)
                .onDisappear {
                    // Update card icon immediately when user selects one
                    if let icon = editedIcon {
                        card.setIcon(icon)
                        try? modelContext.save()
                    }
                }
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Card icon
                Button(action: {
                    if isEditing {
                        showingIconSelection = true
                    }
                }) {
                    CardIconDisplay(icon: card.getIcon() ?? CardIcon.sfSymbol(barcodeIcon(for: card.barcodeType)), size: 50)
                        .overlay(
                            Group {
                                if isEditing {
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.appBlue)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .offset(x: 18, y: -18)
                                }
                            }
                        )
                }
                .disabled(!isEditing)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let personName = card.metadata["personName"], !personName.isEmpty {
                        Text("For: \(personName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let locationName = card.locationName, !locationName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.appBlue)
                                .font(.caption)
                            Text(locationName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func barcodeIcon(for type: BarcodeType) -> String {
        switch type {
        case .qr:
            return "qrcode"
        case .code128, .ean13, .upcA:
            return "barcode"
        case .pdf417:
            return "doc.text"
        case .aztec:
            return "square.grid.2x2"
        case .code39, .itf:
            return "barcode.viewfinder"
        }
    }
    
    private var barcodeSection: some View {
        VStack(spacing: 12) {
            Text("Barcode")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .cornerRadius(8)

                // Priority 1: User prefers cropped AND it's available
                if card.prefersCroppedBarcode, let cropped = croppedBarcodeImage {
                    croppedBarcodeView(cropped)
                }
                // Priority 2: Generate barcode (default behavior)
                else if let generated = generateBarcode() {
                    generatedBarcodeView(generated)
                }
                // Priority 3: FALLBACK - show cropped when generation fails
                else if let cropped = croppedBarcodeImage {
                    croppedBarcodeView(cropped)
                        .overlay(alignment: .bottom) {
                            Text("Using scanned barcode image")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(4)
                                .background(Color.white.opacity(0.8))
                                .cornerRadius(4)
                                .padding(.bottom, 8)
                        }
                }
                // Priority 4: Nothing available - show error
                else {
                    errorStateView
                }
            }
            .frame(height: 200)
            .onTapGesture(count: 2) {
                toggleBarcodeDisplay()
            }
            .overlay(alignment: .topTrailing) {
                toggleHintIcon
            }

            if isEditing {
                brightnessControlSection
            }
        }
        .onAppear {
            loadCroppedBarcodeImage()
        }
    }

    // View for displaying cropped barcode image
    private func croppedBarcodeView(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(16)
    }

    // View for displaying generated barcode
    private func generatedBarcodeView(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(16)
            .brightness(brightness - 1.0)
    }

    // Error state when no barcode is available
    private var errorStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.appLightGray)

            Text("Unable to display barcode")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Button(action: {
                showingRescan = true
            }) {
                HStack {
                    Image(systemName: "camera.viewfinder")
                    Text("Rescan Barcode")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.appBlue)
                .cornerRadius(8)
            }
        }
        .padding()
    }

    // Visual hint icon for double-tap toggle
    @ViewBuilder
    private var toggleHintIcon: some View {
        let canGenerate = generateBarcode() != nil
        let hasCropped = croppedBarcodeImage != nil

        if canGenerate && hasCropped {
            Image(systemName: "arrow.2.squarepath")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
                .padding(8)
        }
    }

    // Toggle between generated and cropped barcode
    private func toggleBarcodeDisplay() {
        let canGenerate = generateBarcode() != nil
        let hasCropped = croppedBarcodeImage != nil

        // Only toggle if both options exist
        guard canGenerate && hasCropped else { return }

        // Toggle preference and persist to model
        card.prefersCroppedBarcode.toggle()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    // Load cropped barcode image on appear
    private func loadCroppedBarcodeImage() {
        guard !isLoadingCroppedImage else { return }

        isLoadingCroppedImage = true

        Task {
            let cropper = BarcodeImageCropper()

            // Try loading from cache first
            if let cachedURL = card.croppedBarcodeImageURL,
               let cached = cropper.loadCroppedBarcodeImage(from: cachedURL) {
                await MainActor.run {
                    croppedBarcodeImage = cached
                    isLoadingCroppedImage = false
                }
                return
            }

            // Generate and cache if not available
            if let url = await cropper.cropAndCacheBarcodeImage(for: card) {
                card.croppedBarcodeImageURL = url
                if let image = cropper.loadCroppedBarcodeImage(from: url) {
                    await MainActor.run {
                        croppedBarcodeImage = image
                        isLoadingCroppedImage = false
                    }
                }
            }

            await MainActor.run {
                isLoadingCroppedImage = false
            }
        }
    }
    
    private var brightnessControlSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.yellow)
                Text("Brightness")
                Spacer()
                Text("\(Int(brightness * 100))%")
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $brightness, in: 0.5...1.5)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var cardInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Information")
                .font(.headline)
            
            if isEditing {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Card Name", text: $editedName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Person Name (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., John Doe", text: $editedPersonName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Place Name (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., Local Library", text: $editedLocationName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .onChange(of: editedLocationName) { oldValue, newValue in
                                // Capitalize first letter of each word
                                let capitalized = newValue.split(separator: " ")
                                    .map { $0.prefix(1).capitalized + $0.dropFirst().lowercased() }
                                    .joined(separator: " ")
                                if capitalized != newValue {
                                    editedLocationName = capitalized
                                }
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Add a note about this card...", text: $editedNote, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("PIN (Optional)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter PIN code", text: $editedPin)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                }
            } else {
                // Only show meaningful information - removed useless "Type Code 39"
                if let validTo = card.validTo {
                    DetailInfoRow(
                        label: "Expires",
                        value: validTo.formatted(date: .abbreviated, time: .omitted),
                        valueColor: card.isExpired ? Color.red : .primary
                    )
                }
                
                if card.oneTime {
                    DetailInfoRow(
                        label: "One-Time Use",
                        value: card.usedAt != nil ? "Used" : "Available",
                        valueColor: card.usedAt != nil ? Color.red : Color.green
                    )
                }
                
                if let note = card.metadata["note"], !note.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(note)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 4)
                }

                if let pin = card.metadata["pin"], !pin.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PIN")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.appBlue)
                                .font(.caption)
                            Text(pin)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                            Button(action: {
                                UIPasteboard.general.string = pin
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy")
                                }
                                .font(.caption)
                                .foregroundColor(.appBlue)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var networksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where This Card Can Be Used")
                .font(.headline)
                .foregroundColor(.primary)

            let hasLocation = !(card.locationName ?? "").isEmpty
            let hasNetworks = !networks.isEmpty

            if !hasLocation && !hasNetworks {
                VStack(spacing: 12) {
                    Text("No locations found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: {
                        showingAddPlace = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add a Place")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.appBlue)
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 8)
            } else {
                // Show location name first if it exists
                if let locationName = card.locationName, !locationName.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.appBlue)
                            .font(.title3)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(locationName)
                                .font(.body)
                                .foregroundColor(.primary)

                            Text("Location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)

                    if hasNetworks {
                        Divider()
                    }
                }

                // Show curated networks
                ForEach(networks) { network in
                    HStack(spacing: 12) {
                        Image(systemName: network.category.icon)
                            .foregroundColor(.appBlue)
                            .font(.title3)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(network.name)
                                .font(.body)
                                .foregroundColor(.primary)

                            Text(network.category.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)

                    if network != networks.last {
                        Divider()
                    }
                }

                Button(action: {
                    showingAddPlace = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Another Place")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appBlue)
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var websiteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Website")
                .font(.headline)

            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Website URL (Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.appBlue)

                        TextField("https://example.com", text: $editedWebsiteUrl)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                }
            } else if let websiteUrl = card.metadata["websiteUrl"], !websiteUrl.isEmpty {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.appBlue)

                    Link(websiteUrl, destination: URL(string: websiteUrl) ?? URL(string: "https://example.com")!)
                        .font(.subheadline)
                        .foregroundColor(.appBlue)

                    Spacer()

                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.appBlue)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - OCR Sections

    private func extractedTextSection(ocrData: OCRData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Extracted Text")
                    .font(.headline)

                Spacer()

                // Show extraction date and confidence
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Extracted: \(ocrData.extractedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Confidence: \(Int(ocrData.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(ocrData.confidence > 0.7 ? .green : .orange)
                }
            }

            // Full text editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Full Text")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $editedFullText)
                    .frame(minHeight: 100, maxHeight: 200)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }

            Divider()
                .padding(.vertical, 4)

            // Segmented fields
            VStack(alignment: .leading, spacing: 12) {
                Text("Detected Fields")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                ForEach($editedOCRSegments) { $segment in
                    OCRFieldRow(field: $segment)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var extractTextButtonSection: some View {
        VStack(spacing: 12) {
            Text("Extract text from card image")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: {
                extractTextFromImage()
            }) {
                HStack(spacing: 8) {
                    if isExtractingText {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "doc.text.viewfinder")
                        Text("Extract Text")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appBlue)
                .cornerRadius(12)
            }
            .disabled(isExtractingText)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func decryptPayload() async {
        // Get the master key from KeychainService
        let keychainService = KeychainService()
        
        do {
            guard let masterKey = try keychainService.getMasterKey() else {
                errorMessage = "Unable to decrypt card. Master key not found."
                showingError = true
                return
            }
            
            decryptedPayload = try card.decryptPayload(masterKey: masterKey)
        } catch {
            errorMessage = "Failed to decrypt card: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func generateBarcode() -> UIImage? {
        guard let payload = decryptedPayload else {
            return nil
        }
        
        let service = BarcodeService()
        let size = CGSize(width: 600, height: 300)
        
        do {
            return try service.renderBarcode(payload: payload, type: card.barcodeType, size: size)
        } catch {
            print("Error generating barcode: \(error)")
            return nil
        }
    }

    private func extractTextFromImage() {
        guard let imageURLString = card.displayImageURL else {
            errorMessage = "No card image available to extract text from"
            showingError = true
            return
        }

        let imageURL = URL(fileURLWithPath: imageURLString)

        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            errorMessage = "Failed to load card image"
            showingError = true
            return
        }

        isExtractingText = true

        Task {
            do {
                // Perform OCR
                let ocrResult = try await VisionOCRService.shared.analyzeCardImage(image)

                // Parse data
                let parsedData = await CardDataParser.shared.parseFromVisionOCR(ocrResult, userLocation: nil)

                // Detect segments
                let segments = OCRSegmentDetector.shared.detectSegments(from: ocrResult, parsedData: parsedData)

                // Create OCR data
                let ocrData = OCRData(
                    fullText: ocrResult.allText,
                    segments: segments,
                    confidence: ocrResult.confidence
                )

                await MainActor.run {
                    // Save to card
                    card.setOCRData(ocrData)

                    // Update edit state
                    editedFullText = ocrData.fullText
                    editedOCRSegments = ocrData.segments

                    isExtractingText = false

                    // Save to context
                    try? modelContext.save()
                }
            } catch {
                await MainActor.run {
                    isExtractingText = false
                    errorMessage = "Failed to extract text: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }

    private func loadNetworks() async {
        // Load networks from curated data
        let curatedNetworks = loadCuratedNetworks()
        let cardNetworkIds = card.networkIds
        
        await MainActor.run {
            if cardNetworkIds.isEmpty {
                // Try to match by card name
                networks = curatedNetworks.filter { network in
                    network.matches(card.name)
                }
            } else {
                networks = curatedNetworks.filter { network in
                    cardNetworkIds.contains(network.id)
                }
            }
        }
    }
    
    private func loadCuratedNetworks() -> [Network] {
        // Load from curated networks JSON or use hardcoded common ones
        return [
            Network(
                id: "costco",
                name: "Costco Wholesale",
                canonicalNames: ["Costco", "Costco Wholesale", "Costco Warehouse"],
                category: .grocery,
                isLargeArea: false,
                defaultRadiusMeters: 100,
                tags: ["membership", "grocery"]
            ),
            Network(
                id: "whole-foods",
                name: "Whole Foods Market",
                canonicalNames: ["Whole Foods", "Whole Foods Market"],
                category: .grocery,
                isLargeArea: false,
                defaultRadiusMeters: 80,
                tags: ["grocery", "organic"]
            ),
            Network(
                id: "kohls",
                name: "Kohl's",
                canonicalNames: ["Kohl's", "Kohls"],
                category: .retail,
                isLargeArea: false,
                defaultRadiusMeters: 100,
                tags: ["retail"]
            )
        ]
    }
    
    private func saveChanges() {
        card.name = editedName
        
        // Store person name in metadata
        if editedPersonName.isEmpty {
            card.metadata.removeValue(forKey: "personName")
        } else {
            card.metadata["personName"] = editedPersonName
        }
        
        // Capitalize place name properly
        let capitalizedPlaceName = editedLocationName.split(separator: " ")
            .map { $0.prefix(1).capitalized + $0.dropFirst().lowercased() }
            .joined(separator: " ")
        card.locationName = capitalizedPlaceName.isEmpty ? nil : capitalizedPlaceName
        
        if editedNote.isEmpty {
            card.metadata.removeValue(forKey: "note")
        } else {
            card.metadata["note"] = editedNote
        }

        // Save PIN
        if editedPin.isEmpty {
            card.metadata.removeValue(forKey: "pin")
        } else {
            card.metadata["pin"] = editedPin
        }

        // Save card type
        if editedCardType.isEmpty {
            card.metadata.removeValue(forKey: "cardType")
        } else {
            card.metadata["cardType"] = editedCardType
        }

        // Website URL handling
        let originalUrl = card.metadata["websiteUrl"] ?? ""
        let urlChanged = editedWebsiteUrl != originalUrl

        if urlChanged && !editedWebsiteUrl.isEmpty {
            // Validate URL format
            if isValidUrl(editedWebsiteUrl) {
                card.setMetadata(editedWebsiteUrl, for: "websiteUrl")
                showingUrlShareAlert = true
            }
        } else if editedWebsiteUrl.isEmpty && !originalUrl.isEmpty {
            card.setMetadata(nil, for: "websiteUrl")
        }

        // Update icon
        let nameChanged = editedName != card.name
        let locationChanged = capitalizedPlaceName != (card.locationName ?? "")
        _ = card.getIcon() // Check if icon exists

        if let editedIcon = editedIcon {
            // User manually selected icon
            card.setIcon(editedIcon)
        } else if nameChanged || locationChanged {
            // Auto-assign icon based on new name/location
            Task {
                let iconName = await CardIconService.shared.assignIconForCard(
                    name: editedName,
                    locationName: capitalizedPlaceName.isEmpty ? nil : capitalizedPlaceName
                )
                let newIcon = CardIcon.sfSymbol(iconName)
                await MainActor.run {
                    card.setIcon(newIcon)
                    editedIcon = newIcon
                }
            }
        }

        // Save OCR data if edited
        if var ocrData = card.getOCRData() {
            // Update with edited values
            ocrData = OCRData(
                fullText: editedFullText,
                segments: editedOCRSegments,
                extractedAt: ocrData.extractedAt,
                confidence: ocrData.confidence,
                algorithmVersion: ocrData.algorithmVersion
            )
            card.setOCRData(ocrData)
        }

        card.updatedAt = Date()

        // Check database for matching networks after updating place name
        if !capitalizedPlaceName.isEmpty {
            Task {
                await checkDatabaseForPlace(capitalizedPlaceName)
            }
        }
        
        // Save to SwiftData context
        try? modelContext.save()
    }
    
    private func checkDatabaseForPlace(_ placeName: String) async {
        // Check curated networks for matches
        let curatedNetworks = loadCuratedNetworks()
        let matchedNetworks = curatedNetworks.filter { network in
            network.matches(placeName)
        }
        
        await MainActor.run {
            if !matchedNetworks.isEmpty {
                // Update card's networkIds if we found matches
                let matchedIds = matchedNetworks.map { $0.id }
                card.networkIds = Array(Set(card.networkIds + matchedIds))
                
                // Reload networks to show the new matches
                Task {
                    await loadNetworks()
                }
            }
        }
    }
    
    private func updateCardBarcode(payload: String, type: BarcodeType) async {
        let keychainService = KeychainService()
        
        do {
            guard let masterKey = try keychainService.getMasterKey() else {
                errorMessage = "Unable to encrypt card. Master key not found."
                showingError = true
                return
            }
            
            // Encrypt the new payload
            guard let data = payload.data(using: .utf8) else {
                errorMessage = "Invalid payload data"
                showingError = true
                return
            }
            
            let nonce = AES.GCM.Nonce()
            let sealedBox = try AES.GCM.seal(data, using: masterKey, nonce: nonce)
            
            // Combine nonce, ciphertext, and tag into single Data blob
            var encryptedData = Data()
            encryptedData.append(nonce.withUnsafeBytes { Data($0) })
            encryptedData.append(sealedBox.ciphertext)
            encryptedData.append(sealedBox.tag)
            
            // Update card
            card.payloadEncrypted = encryptedData
            card.barcodeType = type
            card.updatedAt = Date()
            
            // Refresh decrypted payload
            decryptedPayload = payload

            // Save to SwiftData context
            try? modelContext.save()
        } catch {
            errorMessage = "Failed to update barcode: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func isValidUrl(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    private func applyUrlToAllBrandCards() {
        let brandName = card.brandName
        let websiteUrl = editedWebsiteUrl

        // Fetch all non-archived cards
        let allCards = try? modelContext.fetch(FetchDescriptor<CardModel>(
            predicate: #Predicate { card in
                card.archivedAt == nil
            }
        ))

        guard let cards = allCards else { return }

        for otherCard in cards {
            if otherCard.brandName == brandName {
                otherCard.setMetadata(websiteUrl, for: "websiteUrl")
            }
        }

        try? modelContext.save()
    }
}

// Rescan view for CardModel - uses the actual scanner
struct BarcodeRescanViewForCardModel: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    let card: CardModel
    let onBarcodeScanned: (String, BarcodeType) -> Void
    
    @State private var scannedCode: String?
    @State private var detectedBarcodeType: BarcodeType?
    @State private var showingSaveSheet = false
    @State private var resetScanner = false
    
    var body: some View {
        #if !os(visionOS)
        NavigationStack {
            BarcodeScannerViewForRescan(
                resetTrigger: resetScanner,
                onBarcodeScanned: { code, type in
                    scannedCode = code
                    detectedBarcodeType = type
                    showingSaveSheet = true
                }
            )
            .sheet(isPresented: $showingSaveSheet) {
                if let code = scannedCode, let type = detectedBarcodeType {
                    RescanConfirmationView(
                        card: card,
                        newPayload: code,
                        newType: type,
                        onConfirm: {
                            onBarcodeScanned(code, type)
                            dismiss()
                        },
                        onCancel: {
                            showingSaveSheet = false
                            // Reset scanner to allow rescanning
                            resetScanner.toggle()
                            scannedCode = nil
                            detectedBarcodeType = nil
                        }
                    )
                }
            }
        }
        #else
        NavigationView {
            Text("Barcode scanning is not available on this device.")
                .foregroundColor(.secondary)
                .padding()
        }
        #endif
    }
}

#if !os(visionOS)
// Wrapper for BarcodeScannerView that handles rescan mode
struct BarcodeScannerViewForRescan: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = BarcodeScannerViewModel()
    let resetTrigger: Bool
    let onBarcodeScanned: (String, BarcodeType) -> Void
    
    @State private var scannedCode: String?
    @State private var detectedBarcodeType: BarcodeType?
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: scanner.session)
                .ignoresSafeArea()
            
            // Overlay (same as main scanner)
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
                Text("Rescan Barcode")
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
            }
        }
        .toolbarBackground(Color.black.opacity(0.6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            scanner.resetScanning()
        }
        .onDisappear {
            scanner.stopScanning()
        }
        .onChange(of: resetTrigger) { _, _ in
            // Reset scanner when reset trigger changes
            scanner.resetScanning()
        }
        .onChange(of: scanner.scanSuccess) { oldValue, newValue in
            // Wait for scan success before showing confirmation
            if newValue, let code = scanner.scannedCode, let type = scanner.detectedType {
                // Small delay to show success animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onBarcodeScanned(code, type)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Confirmation view for rescan
struct RescanConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    let card: CardModel
    let newPayload: String
    let newType: BarcodeType
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.appGreen)
                    
                    Text("Barcode Scanned Successfully")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Update \"\(card.name)\" with the new barcode?")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Text("Update Card")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.appPrimary)
                            .cornerRadius(12)
                    }
                    
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle("Confirm Update")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif

// Add Place view for CardModel
struct AddPlaceViewForCardModel: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    let card: CardModel
    let onPlaceAdded: (String) -> Void

    @State private var placeName: String = ""
    @State private var locationLatitude: Double? = nil
    @State private var locationLongitude: Double? = nil
    @State private var locationAddress: String? = nil
    @State private var notes: String = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Location Search with autocomplete
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.appBlue)
                                .frame(width: 20)
                            Text("Location")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.appBlue)
                        }

                        LocationSearchField(
                            locationName: $placeName,
                            latitude: $locationLatitude,
                            longitude: $locationLongitude,
                            address: $locationAddress,
                            placeholder: "Search for a place",
                            modelContext: modelContext
                        )
                    }

                    // Address Display (auto-populated, read-only)
                    if let address = locationAddress, !address.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.appBlue)
                                    .frame(width: 20)
                                Text("Address")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.appBlue)
                            }

                            Text(address)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.appBlue.opacity(0.05))
                                .cornerRadius(12)
                        }
                    }

                    // Notes (Optional)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "note.text")
                                .foregroundColor(.appBlue)
                                .frame(width: 20)
                            Text("Notes (Optional)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.appBlue)
                        }

                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .cornerRadius(12)
                    }

                    // Privacy notice
                    Text("Help us improve our service by sharing where you use this card. This information is anonymous and won't include any card details.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)

                    // Submit button
                    Button(action: submitPlace) {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .tint(.white)
                            } else {
                                Text("Add Place")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(placeName.isEmpty || isSubmitting ? Color.gray.opacity(0.3) : Color.appBlue)
                        .cornerRadius(12)
                    }
                    .disabled(placeName.isEmpty || isSubmitting)
                }
                .padding()
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Add Place")
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
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {
                    onPlaceAdded(placeName)
                    dismiss()
                }
            } message: {
                Text("Place added successfully. Thank you for contributing!")
            }
        }
    }

    private func submitPlace() {
        guard !placeName.isEmpty else { return }

        isSubmitting = true

        Task {
            // In a real implementation, this would call an API
            // For now, we'll just simulate success
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay

            await MainActor.run {
                isSubmitting = false
                showSuccess = true
            }
        }
    }
}

struct DetailInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    NavigationStack {
        CardDetailView(card: CardModel(
            userId: "test",
            name: "Test Card",
            barcodeType: .qr,
            payloadEncrypted: Data()
        ))
    }
}
