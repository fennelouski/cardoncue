import SwiftUI
import PhotosUI
import SwiftData

private enum PhotoImportPhase: Equatable {
    case idle
    case loading
    case processing(current: Int, total: Int)
    case summary(autoSaved: Int, reviewed: Int, failed: Int)
    case reviewing
}

struct PhotoLibraryImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.isInAddCardFlow) private var isInAddCardFlow

    var isActive: Bool = false

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var phase: PhotoImportPhase = .idle
    @State private var showingManualEntry = false
    @State private var showPhotoPicker = false
    @State private var hasAutoPresentedPicker = false

    @State private var reviewQueue: [PhotoImportReviewItem] = []
    @State private var reviewIndex = 0
    @State private var showingReviewSheet = false
    @State private var autoSavedCount = 0
    @State private var reviewedCount = 0
    @State private var failedCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    content
                    Spacer()
                }
                .padding(.top, isInAddCardFlow
                    ? AddCardFlowMetrics.headerHeight(hasModeSelector: false) + 16
                    : 60)
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isInAddCardFlow {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.appBlue)
                    }

                    ToolbarItem(placement: .principal) {
                        Text("Import Photo")
                            .foregroundColor(.appBlue)
                            .fontWeight(.semibold)
                    }
                }
            }
            .toolbar(isInAddCardFlow ? .hidden : .visible, for: .navigationBar)
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedItems,
                maxSelectionCount: PhotoImportService.maxSelectionCount,
                matching: .images
            )
            .onChange(of: isActive) { _, active in
                if active {
                    maybeAutoPresentPicker()
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                startBatchImport(items: newItems)
            }
            .sheet(isPresented: $showingReviewSheet, onDismiss: finishReviewFlow) {
                if reviewIndex < reviewQueue.count {
                    let item = reviewQueue[reviewIndex]
                    ScannedCardReviewView(
                        barcodeNumber: item.barcodePayload,
                        barcodeType: item.barcodeType,
                        capturedImage: item.capturedImage,
                        barcodeBoundingBox: item.boundingBox,
                        reviewProgressLabel: String(
                            format: NSLocalizedString(
                                "photo_import_review_progress",
                                comment: "Batch review progress label"
                            ),
                            reviewIndex + 1,
                            reviewQueue.count
                        ),
                        dismissesOnSave: false,
                        onSave: {
                            reviewedCount += 1
                            advanceReviewQueue()
                        },
                        onRescan: {
                            advanceReviewQueue()
                        }
                    )
                    .id(item.id)
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            idleContent
        case .loading:
            loadingContent(message: NSLocalizedString("photo_import_loading", comment: "Loading selected photos"))
        case .processing(let current, let total):
            loadingContent(
                message: String(
                    format: NSLocalizedString("photo_import_processing", comment: "Processing photos progress"),
                    current,
                    total
                )
            )
        case .summary(let autoSaved, let reviewed, let failed):
            summaryContent(autoSaved: autoSaved, reviewed: reviewed, failed: failed)
        case .reviewing:
            loadingContent(message: NSLocalizedString("photo_import_preparing_review", comment: "Preparing review queue"))
        }
    }

    private var idleContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.appBlue)

            VStack(spacing: 12) {
                Text(NSLocalizedString("import_photo_title", comment: "Import from photo feature title"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.appBlue)

                Text(NSLocalizedString("photo_import_multi_description", comment: "Multi-photo import description"))
                    .font(.subheadline)
                    .foregroundColor(.appLightGray)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showPhotoPicker = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.fill")
                        .font(.title3)
                    Text(NSLocalizedString("choose_photos", comment: "Choose photos button"))
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.appPrimary)
                .cornerRadius(12)
            }

            Button(action: { showingManualEntry = true }) {
                Text(NSLocalizedString("enter_manually_instead", comment: "Manual entry fallback"))
                    .font(.subheadline)
                    .foregroundColor(.appBlue)
            }
        }
    }

    private func loadingContent(message: String) -> some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.appPrimary)

            Text(message)
                .font(.headline)
                .foregroundColor(.appBlue)
                .multilineTextAlignment(.center)
        }
    }

    private func summaryContent(autoSaved: Int, reviewed: Int, failed: Int) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.appGreen)

            Text(NSLocalizedString("photo_import_summary_title", comment: "Import summary title"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.appBlue)

            VStack(alignment: .leading, spacing: 12) {
                summaryRow(
                    label: NSLocalizedString("photo_import_summary_auto_saved", comment: "Auto-saved count"),
                    value: autoSaved
                )
                summaryRow(
                    label: NSLocalizedString("photo_import_summary_reviewed", comment: "Reviewed count"),
                    value: reviewed
                )
                summaryRow(
                    label: NSLocalizedString("photo_import_summary_failed", comment: "Failed count"),
                    value: failed
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.appBlue.opacity(0.06))
            .cornerRadius(12)

            VStack(spacing: 12) {
                Button(action: resetForAnotherImport) {
                    Text(NSLocalizedString("photo_import_import_more", comment: "Import more photos"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                }

                if failed > 0 {
                    Button(action: { showingManualEntry = true }) {
                        Text(NSLocalizedString("photo_import_enter_failed_manually", comment: "Enter failed manually"))
                            .font(.subheadline)
                            .foregroundColor(.appBlue)
                    }
                }

                Button(action: { dismiss() }) {
                    Text(NSLocalizedString("photo_import_done", comment: "Done importing"))
                        .font(.subheadline)
                        .foregroundColor(.appBlue)
                }
            }
        }
    }

    private func summaryRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.appLightGray)
            Spacer()
            Text("\(value)")
                .fontWeight(.semibold)
                .foregroundColor(.appBlue)
        }
    }

    private func maybeAutoPresentPicker() {
        guard !hasAutoPresentedPicker, phase == .idle else { return }
        hasAutoPresentedPicker = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if isActive, phase == .idle {
                showPhotoPicker = true
            }
        }
    }

    private func startBatchImport(items: [PhotosPickerItem]) {
        phase = .loading
        reviewQueue = []
        reviewIndex = 0
        autoSavedCount = 0
        reviewedCount = 0
        failedCount = 0

        Task {
            var images: [UIImage] = []

            for item in items {
                if let image = await loadImage(from: item) {
                    images.append(image)
                } else {
                    await MainActor.run {
                        failedCount += 1
                    }
                }
            }

            guard !images.isEmpty else {
                await MainActor.run {
                    phase = .summary(autoSaved: 0, reviewed: 0, failed: failedCount)
                    selectedItems = []
                }
                return
            }

            var pendingReview: [PhotoImportReviewItem] = []

            for (index, image) in images.enumerated() {
                await MainActor.run {
                    phase = .processing(current: index + 1, total: images.count)
                }

                let result = await PhotoImportService.processAndSaveImage(image, modelContext: modelContext)

                await MainActor.run {
                    switch result {
                    case .autoSaved:
                        autoSavedCount += 1
                    case .needsReview(let item):
                        pendingReview.append(item)
                    case .failed:
                        failedCount += 1
                    }
                }
            }

            await MainActor.run {
                selectedItems = []
                reviewQueue = pendingReview

                if pendingReview.isEmpty {
                    phase = .summary(
                        autoSaved: autoSavedCount,
                        reviewed: reviewedCount,
                        failed: failedCount
                    )
                } else {
                    phase = .reviewing
                    reviewIndex = 0
                    showingReviewSheet = true
                }
            }
        }
    }

    private func loadImage(from item: PhotosPickerItem) async -> UIImage? {
        guard let imageData = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: imageData) else {
            return nil
        }
        return image
    }

    private func advanceReviewQueue() {
        reviewIndex += 1
        if reviewIndex >= reviewQueue.count {
            showingReviewSheet = false
        }
    }

    private func finishReviewFlow() {
        phase = .summary(
            autoSaved: autoSavedCount,
            reviewed: reviewedCount,
            failed: failedCount
        )
    }

    private func resetForAnotherImport() {
        selectedItems = []
        reviewQueue = []
        reviewIndex = 0
        autoSavedCount = 0
        reviewedCount = 0
        failedCount = 0
        phase = .idle
        showPhotoPicker = true
    }
}

#Preview {
    PhotoLibraryImportView(isActive: true)
        .modelContainer(for: CardModel.self, inMemory: true)
}
