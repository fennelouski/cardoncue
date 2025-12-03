import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct WatchBarcodeImageView: View {
    let payload: String
    let barcodeType: String
    let brightness: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.white)
                
                if let image = generateBarcodeImage(size: geometry.size) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                        .brightness(brightness - 1.0)
                } else {
                    Text("Unable to generate barcode")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
        }
    }
    
    private func generateBarcodeImage(size: CGSize) -> UIImage? {
        let renderer = WatchBarcodeRenderer()
        let barcodeTypeEnum = mapBarcodeType(barcodeType)
        
        do {
            return try renderer.render(
                payload: payload,
                type: barcodeTypeEnum,
                size: size
            )
        } catch {
            print("Error generating barcode: \(error)")
            return nil
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

