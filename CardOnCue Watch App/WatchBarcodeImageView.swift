import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct WatchBarcodeImageView: View {
    let payload: String
    let barcodeType: String
    let brightness: Double
    
    @State private var barcodeImage: UIImage?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // White background for barcode scanning
                Rectangle()
                    .fill(Color.white)
                    .cornerRadius(4)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                } else if let image = barcodeImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                        .brightness(brightness - 1.0)
                        .transition(.opacity)
                } else if let error = error {
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(8)
                }
            }
        }
        .onAppear {
            loadBarcodeImage()
        }
        .onChange(of: payload) { _ in
            loadBarcodeImage()
        }
        .onChange(of: barcodeType) { _ in
            loadBarcodeImage()
        }
    }
    
    private func loadBarcodeImage() {
        // Don't reload if we already have the image for this payload/type
        guard barcodeImage == nil || isLoading else { return }
        
        isLoading = true
        error = nil
        
        // Load asynchronously to avoid blocking UI
        Task.detached(priority: .userInitiated) {
            let barcodeTypeEnum = self.mapBarcodeType(self.barcodeType)
            
            do {
                // Use optimal size for watch screens (larger for better scanner readability)
                let optimalSize = CGSize(width: 250, height: 250)
                let image = try WatchBarcodeRenderer.shared.render(
                    payload: self.payload,
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

