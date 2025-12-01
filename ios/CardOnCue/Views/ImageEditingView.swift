import SwiftUI
import UIKit

struct ImageEditingView: View {
    @Environment(\.dismiss) var dismiss
    let originalImage: UIImage
    let card: Card
    let onSave: (UIImage, ImageEditingMetadata) -> Void

    @State private var editedImage: UIImage
    @State private var metadata: ImageEditingMetadata
    @State private var rotationAngle: Double = 0
    @State private var contrastValue: Double = 1.0
    @State private var brightnessValue: Double = 0.0
    @State private var showingCropView = false
    @State private var showingPerspectiveView = false
    @State private var isEvaluating = false
    @State private var qualityMetrics: BarcodeQualityMetrics?
    @State private var showingSuggestions = false

    init(image: UIImage, card: Card, onSave: @escaping (UIImage, ImageEditingMetadata) -> Void) {
        self.originalImage = image
        self.card = card
        self.onSave = onSave
        _editedImage = State(initialValue: image)
        _metadata = State(initialValue: ImageEditingMetadata())
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                imagePreview

                if let metrics = qualityMetrics {
                    qualityIndicator(metrics)
                }

                Divider()

                editingControls
                    .padding(.vertical, 16)

                Divider()

                bottomToolbar
            }
            .navigationTitle("Edit Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        applyAllEdits()
                        onSave(editedImage, metadata)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                await evaluateQuality()
            }
            .sheet(isPresented: $showingPerspectiveView) {
                PerspectiveCorrectionView(
                    image: originalImage,
                    onApply: { points in
                        metadata.perspectiveCorrectionPoints = points
                        applyAllEdits()
                    }
                )
            }
            .sheet(isPresented: $showingSuggestions) {
                if let metrics = qualityMetrics {
                    SuggestionsSheet(metrics: metrics)
                }
            }
        }
    }

    private var imagePreview: some View {
        GeometryReader { geometry in
            Image(uiImage: editedImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black.opacity(0.1))
    }

    private func qualityIndicator(_ metrics: BarcodeQualityMetrics) -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(qualityColor(metrics.overallScore))
                    .frame(width: 12, height: 12)

                Text(qualityText(metrics.overallScore))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                showingSuggestions = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                    Text("Tips")
                }
                .font(.subheadline)
                .foregroundColor(.appPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
    }

    private func qualityColor(_ score: Double) -> Color {
        if score >= 0.7 {
            return .green
        } else if score >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }

    private func qualityText(_ score: Double) -> String {
        if score >= 0.7 {
            return "Good Quality"
        } else if score >= 0.4 {
            return "Fair Quality"
        } else {
            return "Poor Quality"
        }
    }

    private var editingControls: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                rotationControl

                contrastControl

                brightnessControl

                actionButtons
            }
            .padding(.horizontal, 16)
        }
    }

    private var rotationControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "rotate.right")
                    .foregroundColor(.appPrimary)
                Text("Rotation")
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(rotationAngle))°")
                    .foregroundColor(.secondary)
            }

            Slider(value: $rotationAngle, in: -45...45, step: 1)
                .onChange(of: rotationAngle) { _ in
                    metadata.rotationAngle = rotationAngle
                    applyAllEdits()
                }
        }
    }

    private var contrastControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "circle.lefthalf.filled")
                    .foregroundColor(.appPrimary)
                Text("Contrast")
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "%.1f", contrastValue))
                    .foregroundColor(.secondary)
            }

            Slider(value: $contrastValue, in: 0.5...1.5, step: 0.1)
                .onChange(of: contrastValue) { _ in
                    metadata.contrastAdjustment = contrastValue
                    applyAllEdits()
                }
        }
    }

    private var brightnessControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sun.max")
                    .foregroundColor(.appPrimary)
                Text("Brightness")
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "%.1f", brightnessValue))
                    .foregroundColor(.secondary)
            }

            Slider(value: $brightnessValue, in: -0.5...0.5, step: 0.1)
                .onChange(of: brightnessValue) { _ in
                    metadata.brightnessAdjustment = brightnessValue
                    applyAllEdits()
                }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingPerspectiveView = true
            }) {
                HStack {
                    Image(systemName: "rotate.3d")
                    Text("Straighten Image")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .foregroundColor(.appBlue)
                .cornerRadius(8)
            }

            Button(action: resetEdits) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset All")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.gray.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(8)
            }
        }
    }

    private var bottomToolbar: some View {
        HStack {
            if isEvaluating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                Text("Evaluating...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Button(action: {
                    Task {
                        await evaluateQuality()
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.seal")
                        Text("Re-evaluate Quality")
                    }
                    .font(.subheadline)
                    .foregroundColor(.appPrimary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func applyAllEdits() {
        editedImage = ImageStorageService.shared.applyEditingMetadata(originalImage, metadata: metadata)
    }

    private func resetEdits() {
        rotationAngle = 0
        contrastValue = 1.0
        brightnessValue = 0.0
        metadata = ImageEditingMetadata()
        editedImage = originalImage
    }

    private func evaluateQuality() async {
        isEvaluating = true
        qualityMetrics = await BarcodeQualityService.shared.evaluateImage(
            editedImage,
            expectedBarcodeType: card.barcodeType
        )
        isEvaluating = false
    }
}

struct SuggestionsSheet: View {
    @Environment(\.dismiss) var dismiss
    let metrics: BarcodeQualityMetrics

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Quality Scores")) {
                    scoreRow(label: "Readability", score: metrics.readabilityScore)
                    scoreRow(label: "Sharpness", score: metrics.imageSharpness)
                    scoreRow(label: "Contrast", score: metrics.contrastScore)
                    scoreRow(label: "Overall", score: metrics.overallScore)
                }

                Section(header: Text("Suggestions")) {
                    ForEach(BarcodeQualityService.shared.suggestImprovements(for: metrics), id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 20))

                            Text(suggestion)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Quality Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func scoreRow(label: String, score: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.0f%%", score * 100))
                .fontWeight(.medium)
                .foregroundColor(scoreColor(score))
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 0.7 {
            return .green
        } else if score >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    ImageEditingView(
        image: UIImage(systemName: "photo")!,
        card: Card(
            userId: "test",
            name: "Test Card",
            barcodeType: .qr,
            payload: "12345",
            cardType: .other
        )
    ) { _, _ in }
}
