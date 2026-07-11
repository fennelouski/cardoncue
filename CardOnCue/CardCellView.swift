//
//  CardCellView.swift
//  CardOnCue
//
//  Card-style cell used by the masonry grid on the main list. Replaces the old
//  CardRowView. Shows the brand icon, name, one subtitle line, expiry, a subtle
//  per-card color theme, category symbols, and status badges.
//

import SwiftUI

struct CardCellView: View {
    let card: CardModel
    var onArchive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.appLightGray.opacity(0.25))
                        .frame(width: 52, height: 52)

                    CardIconDisplay(
                        icon: card.getIcon() ?? CardIcon.sfSymbol(barcodeIcon(for: card.barcodeType)),
                        size: card.getIcon()?.type == .image ? 50 : 34
                    )
                }

                Spacer(minLength: 8)

                trailingBadges
            }

            Text(card.name)
                .font(.headline)
                .foregroundColor(.appBlue)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.appLightGray)
                .lineLimit(1)

            if let expiryInfo = card.expiryInfo {
                Text(expiryInfo)
                    .font(.caption)
                    .foregroundColor(card.isExpired ? .red : .appGreen)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [card.themeTint.opacity(0.20), card.themeTint.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.appBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(card.themeTint.opacity(0.30), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive, action: onArchive) {
                Label(
                    NSLocalizedString("archive", value: "Archive", comment: "Archive card action"),
                    systemImage: "archivebox"
                )
            }
        }
    }

    /// Category symbols (up to 3) plus the expired/used status badge.
    private var trailingBadges: some View {
        HStack(spacing: 5) {
            ForEach(Array(card.categories.prefix(3)), id: \.self) { category in
                Image(systemName: category.sfSymbol)
                    .font(.system(size: 11))
                    .foregroundColor(category.tint)
            }

            if card.isExpired {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
            } else if card.oneTime && card.usedAt != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.appGreen)
                    .font(.system(size: 14))
            }
        }
    }

    /// Same subtitle precedence as the old row: cardholder → location → type.
    private var subtitle: String {
        if let cardholder = card.cardholderName {
            return cardholder
        } else if let locationName = card.locationName, !locationName.isEmpty {
            return locationName
        } else {
            return card.barcodeType.displayName
        }
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
