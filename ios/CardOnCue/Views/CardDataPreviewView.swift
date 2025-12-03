import SwiftUI
import UIKit

struct CardDataPreviewView: View {
    let cardImage: UIImage?
    @State var parsedData: ParsedCardData
    let selectedBarcode: DetectedBarcodeData?
    let onConfirm: (ParsedCardData, DetectedBarcodeData?) -> Void
    let onCancel: () -> Void

    @State private var editedCardName: String
    @State private var editedPersonName: String
    @State private var selectedCardType: CardType
    @State private var selectedLocation: LocationSuggestion?

    init(
        cardImage: UIImage?,
        parsedData: ParsedCardData,
        selectedBarcode: DetectedBarcodeData?,
        onConfirm: @escaping (ParsedCardData, DetectedBarcodeData?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.cardImage = cardImage
        self.parsedData = parsedData
        self.selectedBarcode = selectedBarcode
        self.onConfirm = onConfirm
        self.onCancel = onCancel

        _editedCardName = State(initialValue: parsedData.cardName ?? "")
        _editedPersonName = State(initialValue: parsedData.personName ?? "")
        _selectedCardType = State(initialValue: parsedData.cardType ?? .membership)
        _selectedLocation = State(initialValue: parsedData.suggestedLocations.first)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                cardImagePreview

                detectedInfoSection

                editableFieldsSection

                locationSection

                confirmButton
            }
            .padding()
        }
        .navigationTitle("Confirm Card Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cardImagePreview: some View {
        Group {
            if let image = cardImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            }
        }
    }

    private var detectedInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Auto-detected Information")
                    .font(.headline)
            }

            if let barcode = selectedBarcode {
                InfoRow(
                    icon: "barcode",
                    label: "Barcode Type",
                    value: barcode.barcodeType.rawValue.uppercased()
                )

                InfoRow(
                    icon: "number",
                    label: "Barcode Number",
                    value: barcode.payload
                )
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    private var editableFieldsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Card Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Card Name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("Card Name", text: $editedCardName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Cardholder Name (Optional)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("Your Name", text: $editedPersonName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Card Type")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Card Type", selection: $selectedCardType) {
                    ForEach(CardType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var locationSection: some View {
        Group {
            if !parsedData.suggestedLocations.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.appPrimary)
                        Text("Suggested Locations Nearby")
                            .font(.headline)
                    }

                    ForEach(parsedData.suggestedLocations) { location in
                        LocationRow(
                            location: location,
                            isSelected: selectedLocation?.id == location.id,
                            onSelect: {
                                selectedLocation = location
                            }
                        )
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    private var confirmButton: some View {
        Button(action: confirmCard) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Add Card")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.appPrimary)
            .cornerRadius(12)
        }
        .disabled(editedCardName.isEmpty)
    }

    private func confirmCard() {
        var updatedData = parsedData
        updatedData.cardName = editedCardName
        updatedData.personName = editedPersonName.isEmpty ? nil : editedPersonName
        updatedData.cardType = selectedCardType

        if let location = selectedLocation {
            updatedData.suggestedLocations = [location]
        }

        onConfirm(updatedData, selectedBarcode)
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
            }

            Spacer()
        }
    }
}

struct LocationRow: View {
    let location: LocationSuggestion
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .appPrimary : .gray)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(location.address)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let distance = location.distance {
                        Text(formatDistance(distance))
                            .font(.caption2)
                            .foregroundColor(.appPrimary)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.appPrimary.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.appPrimary : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        if miles < 0.1 {
            return "Nearby"
        } else if miles < 1.0 {
            return String(format: "%.1f mi away", miles)
        } else {
            return String(format: "%.0f mi away", miles)
        }
    }
}

#Preview {
    NavigationView {
        CardDataPreviewView(
            cardImage: nil,
            parsedData: ParsedCardData(
                cardName: "Louisville Free Public Library",
                personName: "John Doe",
                cardType: .membership,
                suggestedLocations: [
                    LocationSuggestion(name: "Main Library", address: "123 Main St, Louisville, KY", coordinate: nil, distance: 500)
                ]
            ),
            selectedBarcode: DetectedBarcodeData(
                barcodeType: .code128,
                payload: "123456789",
                confidence: 0.95,
                detectedSymbology: "CODE_128",
                boundingBox: .zero
            ),
            onConfirm: { _, _ in },
            onCancel: {}
        )
    }
}
