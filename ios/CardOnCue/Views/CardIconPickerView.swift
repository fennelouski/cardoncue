import SwiftUI
import PhotosUI

struct CardIconPickerView: View {
    let card: Card
    let onIconUpdated: (Card) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    currentIconSection

                    Divider()

                    uploadSection

                    if card.customIconUrl != nil {
                        Divider()
                        resetSection
                    }
                }
                .padding()
            }
            .navigationTitle("Card Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Upload Error", isPresented: .constant(uploadError != nil)) {
                Button("OK") {
                    uploadError = nil
                }
            } message: {
                Text(uploadError ?? "")
            }
            .confirmationDialog("Reset Icon", isPresented: $showingDeleteConfirmation) {
                Button("Reset to Default", role: .destructive) {
                    Task {
                        await resetToDefault()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove your custom icon and use the default icon for \(card.name).")
            }
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        await uploadCustomIcon(image)
                    }
                }
            }
        }
    }

    private var currentIconSection: some View {
        VStack(spacing: 12) {
            Text("Current Icon")
                .font(.headline)

            CardIconView(card: card, size: 96)

            if let customIconUrl = card.customIconUrl {
                Label("Custom icon", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else if card.defaultIconUrl != nil {
                Label("Default icon", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var uploadSection: some View {
        VStack(spacing: 16) {
            Text("Change Icon")
                .font(.headline)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isUploading)

            if isUploading {
                ProgressView("Uploading...")
                    .padding()
            }

            Text("Select a square image for best results")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var resetSection: some View {
        VStack(spacing: 16) {
            Text("Reset")
                .font(.headline)

            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Reset to Default Icon", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(10)
            }
        }
    }

    private func uploadCustomIcon(_ image: UIImage) async {
        isUploading = true
        defer { isUploading = false }

        do {
            let iconUrl = try await CardIconService.shared.uploadCustomIcon(
                cardId: card.id,
                image: image
            )

            var updatedCard = card
            updatedCard.customIconUrl = iconUrl

            await MainActor.run {
                onIconUpdated(updatedCard)
            }
        } catch {
            await MainActor.run {
                uploadError = "Failed to upload icon: \(error.localizedDescription)"
            }
        }
    }

    private func resetToDefault() async {
        isUploading = true
        defer { isUploading = false }

        do {
            let defaultIconUrl = try await CardIconService.shared.deleteCustomIcon(cardId: card.id)

            var updatedCard = card
            updatedCard.customIconUrl = nil
            updatedCard.defaultIconUrl = defaultIconUrl

            await MainActor.run {
                onIconUpdated(updatedCard)
                dismiss()
            }
        } catch {
            await MainActor.run {
                uploadError = "Failed to reset icon: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    CardIconPickerView(
        card: Card(
            id: "1",
            userId: "user1",
            name: "Costco",
            barcodeType: .qr,
            payload: "12345",
            tags: [],
            networkIds: [],
            oneTime: false,
            usedAt: nil,
            metadata: [:],
            createdAt: Date(),
            updatedAt: Date(),
            defaultIconUrl: "https://logo.clearbit.com/costco.com",
            customIconUrl: nil
        ),
        onIconUpdated: { _ in }
    )
}
