import SwiftUI

struct CardDetailView: View {
    let card: Card
    @EnvironmentObject var storageService: StorageService
    @StateObject private var locationSearch = LocationSearchService()
    @State private var brightness: Double = 1.0
    @State private var isLiveActivityActive = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingIconPicker = false
    @State private var showingAddLocation = false
    @State private var updatedCard: Card?
    @State private var editedName: String = ""
    @State private var editedPersonName: String = ""
    @State private var editedLocationName: String = ""
    @State private var isEditing = false
    @State private var showingLocationSuggestions = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                barcodeSection

                cardIconSection

                cardInfoSection

                locationSection

                if #available(iOS 16.1, *) {
                    liveActivitySection
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(isEditing ? "Edit Card" : card.name)
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
        .sheet(isPresented: $showingIconPicker) {
            CardIconPickerView(card: updatedCard ?? card) { updated in
                updatedCard = updated
            }
        }
        .sheet(isPresented: $showingAddLocation) {
            AddCardLocationView(card: card)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            editedName = (updatedCard ?? card).name
            editedPersonName = (updatedCard ?? card).personName ?? ""
            editedLocationName = (updatedCard ?? card).locationName ?? ""
            locationSearch.searchQuery = (updatedCard ?? card).locationName ?? ""

            if #available(iOS 16.1, *) {
                isLiveActivityActive = LiveActivityService.shared.isActivityActive
                brightness = LiveActivityService.shared.currentBrightness
            }
        }
    }

    private var cardIconSection: some View {
        VStack(spacing: 12) {
            CardIconView(card: updatedCard ?? card, size: 96)

            Button(action: {
                showingIconPicker = true
            }) {
                HStack {
                    Image(systemName: "photo")
                    Text("Customize Icon")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var cardInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Information")
                .font(.headline)
                .foregroundColor(.primary)

            if isEditing {
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
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Place Name (Optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ZStack(alignment: .topLeading) {
                        TextField("e.g., Local Library", text: $locationSearch.searchQuery)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: locationSearch.searchQuery) { newValue in
                                showingLocationSuggestions = !newValue.isEmpty && !locationSearch.suggestions.isEmpty
                            }

                        if showingLocationSuggestions {
                            VStack(alignment: .leading, spacing: 0) {
                                Spacer()
                                    .frame(height: 35)

                                ScrollView {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(locationSearch.suggestions, id: \.self) { suggestion in
                                            Button(action: {
                                                let selectedLocation = locationSearch.selectLocation(suggestion)
                                                editedLocationName = selectedLocation
                                                locationSearch.searchQuery = selectedLocation
                                                showingLocationSuggestions = false
                                            }) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(suggestion.title)
                                                        .font(.body)
                                                        .foregroundColor(.primary)
                                                    if !suggestion.subtitle.isEmpty {
                                                        Text(suggestion.subtitle)
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                            }
                                            .buttonStyle(PlainButtonStyle())

                                            if suggestion != locationSearch.suggestions.last {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                }
            } else {
                InfoRow(label: "Name", value: (updatedCard ?? card).name)

                if let personName = (updatedCard ?? card).personName, !personName.isEmpty {
                    InfoRow(label: "Person", value: personName)
                }

                if let locationName = (updatedCard ?? card).locationName, !locationName.isEmpty {
                    InfoRow(label: "Place", value: locationName)
                }
            }

            InfoRow(label: "Type", value: card.barcodeType.displayName)

            if let expiryInfo = card.expiryInfo {
                InfoRow(
                    label: "Expiry",
                    value: expiryInfo,
                    valueColor: card.isExpired ? .red : .green
                )
            }

            if card.oneTime {
                InfoRow(
                    label: "One-Time Use",
                    value: card.usedAt != nil ? "Used" : "Available",
                    valueColor: card.usedAt != nil ? .red : .green
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var locationSection: some View {
        VStack(spacing: 12) {
            Text("Help Improve Our Service")
                .font(.headline)

            VStack(spacing: 12) {
                Text("Share where you use this card to help us understand how our users utilize their memberships and loyalty cards")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: {
                    showingAddLocation = true
                }) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Add Location")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }

    private var barcodeSection: some View {
        VStack(spacing: 12) {
            Text("Barcode")
                .font(.headline)

            ZStack {
                Rectangle()
                    .fill(Color.white)
                    .cornerRadius(8)

                if let image = generateBarcode() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(16)
                        .brightness(brightness - 1.0)
                }
            }
            .frame(height: 200)

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
                    .onChange(of: brightness) { newValue in
                        if #available(iOS 16.1, *), isLiveActivityActive {
                            Task {
                                do {
                                    try await LiveActivityService.shared.updateBrightness(newValue)
                                } catch {
                                    print("Failed to update brightness: \(error)")
                                }
                            }
                        }
                    }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }

    @available(iOS 16.1, *)
    private var liveActivitySection: some View {
        VStack(spacing: 16) {
            Text("Live Activity")
                .font(.headline)

            VStack(spacing: 12) {
                Text("Display this card on your Lock Screen and Dynamic Island for quick access")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: toggleLiveActivity) {
                    HStack {
                        Image(systemName: isLiveActivityActive ? "stop.circle.fill" : "play.circle.fill")
                        Text(isLiveActivityActive ? "Stop Live Activity" : "Start Live Activity")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLiveActivityActive ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }

    @available(iOS 16.1, *)
    private func toggleLiveActivity() {
        if isLiveActivityActive {
            LiveActivityService.shared.endCurrentActivity()
            isLiveActivityActive = false
        } else {
            do {
                try LiveActivityService.shared.startActivity(for: card)
                isLiveActivityActive = true
            } catch {
                errorMessage = "Failed to start Live Activity. Please ensure Live Activities are enabled in Settings."
                showError = true
            }
        }
    }

    private func generateBarcode() -> UIImage? {
        let renderer = BarcodeRenderer()
        let size = CGSize(width: 600, height: 300)

        do {
            return try renderer.render(
                payload: card.payload,
                type: card.barcodeType,
                size: size
            )
        } catch {
            print("Error generating barcode: \(error)")
            return nil
        }
    }

    private func saveChanges() {
        var modified = updatedCard ?? card
        modified.name = editedName
        modified.personName = editedPersonName.isEmpty ? nil : editedPersonName
        modified.locationName = editedLocationName.isEmpty ? nil : editedLocationName
        modified.updatedAt = Date()

        storageService.updateCard(modified)
        updatedCard = modified
    }
}

struct InfoRow: View {
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

extension BarcodeType {
    var displayName: String {
        switch self {
        case .qr:
            return "QR Code"
        case .code128:
            return "Code 128"
        case .pdf417:
            return "PDF417"
        case .aztec:
            return "Aztec"
        case .ean13:
            return "EAN-13"
        case .upcA:
            return "UPC-A"
        case .code39:
            return "Code 39"
        case .itf:
            return "ITF"
        }
    }
}

extension Card {
    var expiryInfo: String? {
        if let daysUntilExpiration = daysUntilExpiration {
            if daysUntilExpiration <= 0 {
                return "Expired"
            } else if daysUntilExpiration <= 7 {
                return "Expires in \(daysUntilExpiration) days"
            } else if daysUntilExpiration <= 30 {
                return "Expires in \(daysUntilExpiration) days"
            }
        }
        return nil
    }
}