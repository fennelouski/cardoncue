import SwiftUI
import UIKit

struct BarcodeRescanView: View {
    @Environment(\.dismiss) var dismiss
    let card: Card
    let onBarcodeScanned: (String, BarcodeType) -> Void
    
    @State private var capturedImage: UIImage?
    @State private var showingBarcodeDetection = false
    
    var body: some View {
        NavigationView {
            Group {
                if let image = capturedImage {
                    BarcodeDetectionView(image: image) { detectedBarcode in
                        onBarcodeScanned(detectedBarcode.payload, detectedBarcode.barcodeType)
                        dismiss()
                    }
                } else {
                    CameraCaptureView(mode: .barcodeImage) { image in
                        capturedImage = image
                        showingBarcodeDetection = true
                    }
                }
            }
            .navigationTitle("Rescan Barcode")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

