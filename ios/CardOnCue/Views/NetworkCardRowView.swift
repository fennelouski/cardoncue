import SwiftUI

struct NetworkCardRowView: View {
    let card: Card
    let isSelected: Bool
    let showDistance: Bool
    let distance: String?

    init(card: Card, isSelected: Bool = false, showDistance: Bool = false, distance: String? = nil) {
        self.card = card
        self.isSelected = isSelected
        self.showDistance = showDistance
        self.distance = distance
    }

    var body: some View {
        HStack(spacing: 16) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .appPrimary : .appLightGray)
                .font(.system(size: 24))

            // Card icon/type indicator
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appLightGray.opacity(0.2))
                    .frame(width: 50, height: 35)

                Image(systemName: barcodeIcon(for: card.barcodeType))
                    .foregroundColor(.appBlue)
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(.appBlue)

                HStack(spacing: 8) {
                    Text(card.barcodeType.displayName)
                        .font(.caption)
                        .foregroundColor(.appLightGray)

                    if showDistance, let distance = distance {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.appLightGray)

                        Text(distance)
                            .font(.caption)
                            .foregroundColor(.appLightGray)
                    }
                }

                // Show expiry warning if applicable
                if let expiryInfo = card.expiryInfo {
                    Text(expiryInfo)
                        .font(.caption)
                        .foregroundColor(card.isExpired ? .red : .appGreen)
                }

                // Show one-time use status
                if card.oneTime {
                    HStack(spacing: 4) {
                        Image(systemName: card.usedAt != nil ? "checkmark.circle.fill" : "circle")
                            .font(.caption2)
                        Text(card.usedAt != nil ? "Used" : "One-time use")
                            .font(.caption2)
                    }
                    .foregroundColor(card.usedAt != nil ? .appLightGray : .appPrimary)
                }
            }

            Spacer()

            // Chevron if interactive
            if !isSelected {
                Image(systemName: "chevron.right")
                    .foregroundColor(.appLightGray)
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.appPrimary.opacity(0.1) : Color.appBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? Color.appPrimary : Color.appLightGray.opacity(0.2),
                    lineWidth: isSelected ? 2 : 1
                )
        )
    }

    private func barcodeIcon(for type: BarcodeType) -> String {
        switch type {
        case .qr:
            return "qrcode"
        case .code128, .ean13, .upcA:
            return "barcode"
        case .pdf417:
            return "doc.text"
        case .aztec:
            return "square.grid.2x2"
        case .code39, .itf:
            return "barcode"
        }
    }
}

extension Card {
    var expiryInfo: String? {
        if let daysUntilExpiration = daysUntilExpiration {
            if daysUntilExpiration <= 0 {
                return "Expired"
            } else if daysUntilExpiration <= 7 {
                return "Expires in \(daysUntilExpiration) days"
            } else if daysUntilExpiration <= 30 {
                return "Expires in \(daysUntilExpiration) days"
            }
        }
        return nil
    }
}

#Preview {
    VStack(spacing: 16) {
        NetworkCardRowView(
            card: Card(
                id: "1",
                userId: "user1",
                name: "Costco Membership",
                barcodeType: .code128,
                payload: "123456789",
                tags: [],
                networkIds: ["costco"],
                validFrom: nil,
                validTo: nil,
                oneTime: false,
                usedAt: nil,
                metadata: [:],
                createdAt: Date(),
                updatedAt: Date()
            ),
            isSelected: true,
            showDistance: true,
            distance: "0.5 mi"
        )

        NetworkCardRowView(
            card: Card(
                id: "2",
                userId: "user1",
                name: "Costco Executive",
                barcodeType: .code128,
                payload: "987654321",
                tags: [],
                networkIds: ["costco"],
                validFrom: nil,
                validTo: Date().addingTimeInterval(86400 * 30),
                oneTime: false,
                usedAt: nil,
                metadata: [:],
                createdAt: Date(),
                updatedAt: Date()
            ),
            isSelected: false,
            showDistance: true,
            distance: "0.5 mi"
        )
    }
    .padding()
    .background(Color.appBackground)
}
