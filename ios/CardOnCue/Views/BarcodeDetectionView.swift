import SwiftUI
import UIKit

struct BarcodeDetectionView: View {
    @Environment(\.dismiss) var dismiss
    let image: UIImage
    let onBarcodeSelected: (DetectedBarcodeData) -> Void

    @State private var detectedBarcodes: [DetectedBarcodeData] = []
    @State private var isDetecting = true
    @State private var selectedBarcode: DetectedBarcodeData?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isDetecting {
                    detectingView
                } else if detectedBarcodes.isEmpty {
                    noBarcodeView
                } else {
                    detectedBarcodesView
                }
            }
            .navigationTitle("Detected Barcodes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if selectedBarcode != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Use This") {
                            if let selected = selectedBarcode {
                                onBarcodeSelected(selected)
                                dismiss()
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .task {
                await detectBarcodes()
            }
        }
    }

    private var detectingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)

            Text("Detecting barcodes...")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noBarcodeView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 45))
                    .foregroundColor(.orange)
            }

            VStack(spacing: 8) {
                Text("No Barcode Detected")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Try taking another photo with better lighting or focus")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button(action: {
                dismiss()
            }) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.appPrimary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var detectedBarcodesView: some View {
        VStack(spacing: 0) {
            // Image preview
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 200)
                .background(Color.black.opacity(0.1))
                .padding(.bottom, 16)

            if detectedBarcodes.count > 1 {
                Text("Multiple barcodes detected. Select the one to use:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(detectedBarcodes.enumerated()), id: \.offset) { index, barcode in
                        BarcodeCard(
                            barcode: barcode,
                            index: index,
                            isSelected: selectedBarcode == barcode,
                            onSelect: {
                                selectedBarcode = barcode
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private func detectBarcodes() async {
        isDetecting = true
        detectedBarcodes = await BarcodeQualityService.shared.detectBarcodes(in: image)

        // Auto-select the first (highest confidence) barcode
        if let first = detectedBarcodes.first {
            selectedBarcode = first
        }

        isDetecting = false
    }
}

struct BarcodeCard: View {
    let barcode: DetectedBarcodeData
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(barcodeTypeLabel)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("Confidence: \(Int(barcode.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.appPrimary)
                    } else {
                        Image(systemName: "circle")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Payload")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(barcode.payload)
                        .font(.body)
                        .fontDesign(.monospaced)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }

                // Quality indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(qualityColor)
                        .frame(width: 8, height: 8)

                    Text(qualityText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var barcodeTypeLabel: String {
        switch barcode.barcodeType {
        case .qr:
            return "QR Code"
        case .code128:
            return "Code 128"
        case .pdf417:
            return "PDF417"
        case .aztec:
            return "Aztec Code"
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

    private var qualityColor: Color {
        if barcode.confidence >= 0.8 {
            return .green
        } else if barcode.confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }

    private var qualityText: String {
        if barcode.confidence >= 0.8 {
            return "High confidence"
        } else if barcode.confidence >= 0.5 {
            return "Medium confidence"
        } else {
            return "Low confidence"
        }
    }
}

#Preview {
    BarcodeDetectionView(
        image: UIImage(systemName: "photo")!,
        onBarcodeSelected: { _ in }
    )
}
