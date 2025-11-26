import SwiftUI
import SwiftData

struct ScannedCardReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let barcodeNumber: String
    let barcodeType: BarcodeType

    var onSave: () -> Void
    var onRescan: () -> Void

    @State private var cardName: String = ""
    @State private var hasExpiryDate: Bool = false
    @State private var expiryDate: Date = Date().addingTimeInterval(365 * 24 * 60 * 60)
    @State private var isOneTime: Bool = false
    @State private var tags: String = ""

    @State private var isLoading: Bool = false
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""

    private let keychainService = KeychainService()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Success header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.appGreen.opacity(0.1))
                                    .frame(width: 80, height: 80)

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.appGreen)
                            }

                            Text("Barcode Scanned!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.appBlue)

                            // Barcode info
                            VStack(spacing: 4) {
                                Text(barcodeType.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.appGreen)

                                Text(barcodeNumber)
                                    .font(.caption)
                                    .foregroundColor(.appLightGray)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .padding(.top, 16)

                        // Form fields
                        VStack(spacing: 20) {
                            // Card Name
                            FormSection(title: "Card Name", icon: "tag.fill") {
                                TextField("e.g., Costco Membership", text: $cardName)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.words)
                            }

                            // Optional: Expiry Date
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle(isOn: $hasExpiryDate) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.appBlue)
                                            .frame(width: 20)
                                        Text("Has Expiry Date")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.appBlue)
                                    }
                                }
                                .tint(.appPrimary)

                                if hasExpiryDate {
                                    DatePicker(
                                        "Expires On",
                                        selection: $expiryDate,
                                        in: Date()...,
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.compact)
                                    .tint(.appPrimary)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                }
                            }

                            // Optional: One-Time Card
                            Toggle(isOn: $isOneTime) {
                                HStack(spacing: 8) {
                                    Image(systemName: "1.circle")
                                        .foregroundColor(.appBlue)
                                        .frame(width: 20)
                                    Text("One-Time Use Card")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.appBlue)
                                }
                            }
                            .tint(.appPrimary)

                            // Optional: Tags
                            FormSection(title: "Tags (Optional)", icon: "tag") {
                                TextField("e.g., Grocery, Membership", text: $tags)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.words)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Action buttons
                        VStack(spacing: 12) {
                            Button(action: saveCard) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.headline)
                                        Text("Save Card")
                                            .font(.headline)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isFormValid ? Color.appPrimary : Color.appLightGray)
                                .cornerRadius(12)
                            }
                            .disabled(!isFormValid || isLoading)

                            Button(action: {
                                onRescan()
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.subheadline)
                                    Text("Scan Again")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.appBlue)
                                .padding(.vertical, 12)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onSave()
                    }
                    .foregroundColor(.appBlue)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isFormValid: Bool {
        !cardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveCard() {
        isLoading = true

        Task {
            do {
                // Get or create master key
                var masterKey = try keychainService.getMasterKey()
                if masterKey == nil {
                    masterKey = try keychainService.generateAndStoreMasterKey()
                }

                guard let key = masterKey else {
                    throw NSError(domain: "CardOnCue", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Failed to get encryption key"
                    ])
                }

                // Parse tags
                let tagArray = tags
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                // Create card with encrypted payload
                let card = try CardModel.createWithEncryptedPayload(
                    userId: "local",
                    name: cardName.trimmingCharacters(in: .whitespacesAndNewlines),
                    barcodeType: barcodeType,
                    payload: barcodeNumber,
                    masterKey: key,
                    tags: tagArray,
                    validTo: hasExpiryDate ? expiryDate : nil,
                    oneTime: isOneTime
                )

                // Save to SwiftData
                await MainActor.run {
                    modelContext.insert(card)
                    try? modelContext.save()
                }

                // Success! Dismiss and call completion
                await MainActor.run {
                    isLoading = false
                    dismiss()
                    onSave()
                }

            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    ScannedCardReviewView(
        barcodeNumber: "1234567890123",
        barcodeType: .qr,
        onSave: {},
        onRescan: {}
    )
    .modelContainer(for: CardModel.self, inMemory: true)
}
