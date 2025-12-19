import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct BarcodeDisplayView: View {
    let card: WatchCardDisplay
    @State private var brightness: Double = 1.0
    @State private var showBrightnessControl = false
    @State private var barcodeScale: CGFloat = 1.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Location badge with improved design
                if let locationName = card.locationName, !locationName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.watchSuccess)
                        Text(locationName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.watchSuccess.opacity(0.2))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.watchSuccess.opacity(0.3), lineWidth: 0.5)
                    )
                }
                
                // Card name with better typography
                Text(card.cardName)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                
                // Barcode type badge - more refined
                Text(card.barcodeType.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.watchCardBackground)
                    )
                
                // Barcode image container with improved design
                VStack(spacing: 8) {
                    WatchBarcodeImageView(
                        payload: card.payload,
                        barcodeType: card.barcodeType,
                        brightness: brightness
                    )
                    .frame(height: 190)
                    .scaleEffect(barcodeScale)
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
                    .onTapGesture {
                        // Tap to toggle brightness control with animation
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showBrightnessControl.toggle()
                            barcodeScale = showBrightnessControl ? 0.98 : 1.0
                        }
                        #if os(watchOS)
                        WKInterfaceDevice.current().play(.click)
                        #endif
                    }
                    .onLongPressGesture(minimumDuration: 0.1) {
                        // Long press for haptic feedback
                        #if os(watchOS)
                        WKInterfaceDevice.current().play(.notification)
                        #endif
                    }
                    
                    // Brightness control with improved design
                    if showBrightnessControl {
                        VStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sun.min")
                                    .font(.system(size: 11))
                                    .foregroundColor(.watchInfo)
                                Slider(value: $brightness, in: 0.5...1.5) { editing in
                                    if !editing {
                                        withAnimation(.spring(response: 0.2)) {
                                            barcodeScale = 1.0
                                        }
                                        #if os(watchOS)
                                        WKInterfaceDevice.current().play(.click)
                                        #endif
                                    }
                                }
                                .tint(.watchPrimary)
                                Image(systemName: "sun.max.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.watchInfo)
                            }
                            .padding(.horizontal, 6)
                            
                            // Brightness percentage with better styling
                            Text("\(Int(brightness * 100))%")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.watchInfo)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.watchInfo.opacity(0.15))
                                )
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.9)),
                            removal: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.9))
                        ))
                    } else {
                        // Hint text with better styling
                        HStack(spacing: 4) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 8))
                            Text("Tap to adjust brightness")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                
                // Card count badge with improved design
                if card.availableCardsCount > 1 {
                    HStack(spacing: 5) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 10))
                        Text("\(card.availableCardsCount) cards available")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.watchInfo)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.watchInfo.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.watchInfo.opacity(0.3), lineWidth: 0.5)
                    )
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
        }
        .navigationTitle("Card")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Load saved brightness preference
            if let savedBrightness = UserDefaults.standard.object(forKey: "watchBarcodeBrightness") as? Double {
                withAnimation {
                    brightness = savedBrightness
                }
            }
        }
        .onChange(of: brightness) { newValue in
            // Save brightness preference
            UserDefaults.standard.set(newValue, forKey: "watchBarcodeBrightness")
        }
    }
}

