import SwiftUI
import SwiftData

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Form fields
    @State private var cardName: String = ""
    @State private var barcodeNumber: String = ""
    @State private var selectedBarcodeType: BarcodeType = .qr
    @State private var hasExpiryDate: Bool = false
    @State private var expiryDate: Date = Date().addingTimeInterval(365 * 24 * 60 * 60) // 1 year from now
    @State private var isOneTime: Bool = false
    @State private var tags: String = ""

    // State
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
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 48))
                                .foregroundColor(.appBlue)

                            Text("Add Card Manually")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.appBlue)

                            Text("Enter your card details below")
                                .font(.subheadline)
                                .foregroundColor(.appLightGray)
                        }
                        .padding(.top, 16)

                        // Form
                        VStack(spacing: 20) {
                            // Card Name
                            FormSection(title: "Card Name", icon: "tag.fill") {
                                TextField("e.g., Costco Membership", text: $cardName)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.words)
                            }

                            // Barcode Type
                            FormSection(title: "Barcode Type", icon: "barcode") {
                                Menu {
                                    ForEach(BarcodeType.allCases, id: \.self) { type in
                                        Button(action: {
                                            selectedBarcodeType = type
                                        }) {
                                            HStack {
                                                Text(type.displayName)
                                                if selectedBarcodeType == type {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedBarcodeType.displayName)
                                            .foregroundColor(.appBlue)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.appLightGray)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                                }
                            }

                            // Barcode Number
                            FormSection(title: "Barcode Number", icon: "number") {
                                TextField("Enter card number or barcode", text: $barcodeNumber)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .keyboardType(.numbersAndPunctuation)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
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

                            // Help Text
                            Text("Tags help organize your cards. Separate multiple tags with commas.")
                                .font(.caption)
                                .foregroundColor(.appLightGray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 24)

                        // Save Button
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
        !cardName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !barcodeNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                    userId: "local", // TODO: Replace with actual user ID when auth is implemented
                    name: cardName.trimmingCharacters(in: .whitespacesAndNewlines),
                    barcodeType: selectedBarcodeType,
                    payload: barcodeNumber.trimmingCharacters(in: .whitespacesAndNewlines),
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

                // Success! Dismiss the view
                await MainActor.run {
                    isLoading = false
                    dismiss()
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

// MARK: - Custom Components

struct FormSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.appBlue)
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.appBlue)
            }

            content
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.white)
            .cornerRadius(12)
    }
}

#Preview {
    ManualEntryView()
        .modelContainer(for: CardModel.self, inMemory: true)
}
