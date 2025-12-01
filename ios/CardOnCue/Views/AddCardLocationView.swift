import SwiftUI

struct AddCardLocationView: View {
    let card: Card
    @Environment(\.dismiss) private var dismiss
    @State private var locationName = ""
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var country = ""
    @State private var postalCode = ""
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location Details")) {
                    TextField("Location Name*", text: $locationName)
                        .autocapitalization(.words)

                    TextField("Address", text: $address)
                        .autocapitalization(.words)

                    TextField("City", text: $city)
                        .autocapitalization(.words)

                    TextField("State/Province", text: $state)
                        .autocapitalization(.words)

                    TextField("Country", text: $country)
                        .autocapitalization(.words)

                    TextField("Postal Code", text: $postalCode)
                        .autocapitalization(.none)
                }

                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }

                Section {
                    Button(action: submitLocation) {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Add Location")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(locationName.isEmpty || isSubmitting)
                }

                Section {
                    Text("Help us improve our service by sharing where you use this card. This information is anonymous and won't include any card details.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Location added successfully. Thank you for contributing!")
            }
        }
    }

    private func submitLocation() {
        guard !locationName.isEmpty else { return }

        isSubmitting = true

        Task {
            do {
                _ = try await CardLocationService.shared.addLocation(
                    for: card.id,
                    userId: card.userId,
                    locationName: locationName,
                    address: address.isEmpty ? nil : address,
                    city: city.isEmpty ? nil : city,
                    state: state.isEmpty ? nil : state,
                    country: country.isEmpty ? nil : country,
                    postalCode: postalCode.isEmpty ? nil : postalCode,
                    latitude: nil,
                    longitude: nil,
                    notes: notes.isEmpty ? nil : notes
                )

                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to add location. Please try again."
                    showError = true
                }
            }
        }
    }
}
