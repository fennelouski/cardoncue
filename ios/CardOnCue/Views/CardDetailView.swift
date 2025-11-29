import SwiftUI

struct CardDetailView: View {
    let card: Card
    @State private var brightness: Double = 1.0
    @State private var isLiveActivityActive = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showingIconPicker = false
    @State private var updatedCard: Card?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                cardIconSection

                cardInfoSection

                barcodeSection

                if #available(iOS 16.1, *) {
                    liveActivitySection
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingIconPicker) {
            CardIconPickerView(card: updatedCard ?? card) { updated in
                updatedCard = updated
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
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
