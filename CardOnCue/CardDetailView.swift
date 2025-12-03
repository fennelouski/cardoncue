import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let card: CardModel
    
    @State private var brightness: Double = 1.0
    @State private var decryptedPayload: String?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                barcodeSection
                
                cardInfoSection
                
                if let locationName = card.locationName {
                    locationSection(locationName: locationName)
                }
            }
            .padding()
        }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .task {
            await decryptPayload()
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
                } else {
                    Text("Unable to display barcode")
                        .foregroundColor(.gray)
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
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var cardInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Information")
                .font(.headline)
            
            VStack(spacing: 8) {
                DetailInfoRow(label: "Type", value: card.barcodeType.displayName)
                
                if let locationName = card.locationName {
                    DetailInfoRow(label: "Location", value: locationName)
                }
                
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
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func locationSection(locationName: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.headline)
            
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.appBlue)
                Text(locationName)
                    .font(.subheadline)
            }
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

