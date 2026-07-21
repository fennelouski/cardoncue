import SwiftUI
import CoreGraphics
#if os(watchOS)
import WatchKit
#endif

struct WatchBarcodeImageView: View {
    let payload: String
    let barcodeType: String
    let brightness: Double
    
    @State private var barcodeImage: CGImage?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // White background for barcode scanning with subtle gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.98)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(8)
                
                if isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.watchPrimary)
                            .scaleEffect(0.9)
                        Text("Generating...")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                } else if let image = barcodeImage {
                    Image(decorative: image, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(10)
                        .brightness(brightness - 1.0)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                } else if let error = error {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(12)
                }
            }
        }
        .onAppear {
            loadBarcodeImage()
        }
        .onChange(of: payload) {
            loadBarcodeImage()
        }
        .onChange(of: barcodeType) {
            loadBarcodeImage()
        }
    }
    
    private func loadBarcodeImage() {
        // Don't reload if we already have the image for this payload/type
        guard barcodeImage == nil || isLoading else { return }
        
        isLoading = true
        error = nil
        
        // Resolve the inputs on the main actor before hopping to a background task,
        // so the detached closure never reaches back into main actor-isolated state.
        let barcodeTypeEnum = mapBarcodeType(barcodeType)
        let payloadToRender = payload

        // Load asynchronously to avoid blocking UI
        Task.detached(priority: .userInitiated) {
            do {
                // Use optimal size for watch screens (larger for better scanner readability)
                let optimalSize = CGSize(width: 250, height: 250)
                let image = try WatchBarcodeRenderer.shared.render(
                    payload: payloadToRender,
                    type: barcodeTypeEnum,
                    size: optimalSize
                )
                
                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.2)) {
                        self.barcodeImage = image
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "Unable to generate barcode"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func mapBarcodeType(_ type: String) -> BarcodeType {
        switch type.lowercased() {
        case "qr":
            return .qr
        case "code128":
            return .code128
        case "pdf417":
            return .pdf417
        case "aztec":
            return .aztec
        case "ean13":
            return .ean13
        case "upc_a":
            return .upcA
        case "code39":
            return .code39
        case "itf":
            return .itf
        default:
            return .qr
        }
    }
}

