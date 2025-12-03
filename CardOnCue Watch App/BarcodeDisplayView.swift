import SwiftUI

struct BarcodeDisplayView: View {
    let card: WatchCardDisplay
    @State private var brightness: Double = 1.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Location info
                if let locationName = card.locationName, !locationName.isEmpty {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.green)
                        Text(locationName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Card name
                Text(card.cardName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                // Barcode type
                Text(card.barcodeType.uppercased())
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // Barcode image
                WatchBarcodeImageView(
                    payload: card.payload,
                    barcodeType: card.barcodeType,
                    brightness: brightness
                )
                .frame(height: 200)
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Brightness control
                VStack(spacing: 8) {
                    Text("Brightness")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "sun.min")
                            .font(.caption)
                        Slider(value: $brightness, in: 0.5...1.5)
                            .tint(.blue)
                        Image(systemName: "sun.max.fill")
                            .font(.caption)
                    }
                    .padding(.horizontal)
                }
                
                // Card count if multiple available
                if card.availableCardsCount > 1 {
                    Text("\(card.availableCardsCount) cards available")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
        .navigationTitle("Card")
        .navigationBarTitleDisplayMode(.inline)
    }
}

