import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct BarcodeDisplayView: View {
    let card: WatchCardDisplay
    @State private var brightness: Double = 1.0
    @State private var showBrightnessControl = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Location badge
                if let locationName = card.locationName, !locationName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text(locationName)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(8)
                }
                
                // Card name
                Text(card.cardName)
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
                
                // Barcode type badge
                Text(card.barcodeType.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
                
                // Barcode image - optimized for watch screens
                WatchBarcodeImageView(
                    payload: card.payload,
                    barcodeType: card.barcodeType,
                    brightness: brightness
                )
                .frame(height: 180)
                .cornerRadius(8)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .onTapGesture {
                    // Tap to toggle brightness control
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBrightnessControl.toggle()
                    }
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.click)
                    #endif
                }
                
                // Brightness control (collapsible)
                if showBrightnessControl {
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "sun.min")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Slider(value: $brightness, in: 0.5...1.5) { editing in
                                if !editing {
                                    // Haptic feedback when done adjusting
                                    #if os(watchOS)
                                    WKInterfaceDevice.current().play(.click)
                                    #endif
                                }
                            }
                            .tint(.blue)
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 4)
                        
                        Text("\(Int(brightness * 100))%")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    // Hint to tap for brightness
                    Text("Tap barcode to adjust brightness")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                
                // Card count badge if multiple available
                if card.availableCardsCount > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.fill")
                            .font(.system(size: 10))
                        Text("\(card.availableCardsCount) cards available")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(6)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .navigationTitle("Card")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load saved brightness preference
            if let savedBrightness = UserDefaults.standard.object(forKey: "watchBarcodeBrightness") as? Double {
                brightness = savedBrightness
            }
        }
        .onChange(of: brightness) { newValue in
            // Save brightness preference
            UserDefaults.standard.set(newValue, forKey: "watchBarcodeBrightness")
        }
    }
}

