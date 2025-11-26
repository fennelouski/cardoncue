import SwiftUI

struct CardListView: View {
    @EnvironmentObject var storageService: StorageService
    @State private var showingScanner = false
    @State private var showingManualEntry = false

    var body: some View {
        NavigationStack {
            Group {
                if storageService.cards.isEmpty {
                    EmptyStateView(onScanCard: {
                        showingScanner = true
                    })
                } else {
                    cardListView
                }
            }
            .navigationTitle(NSLocalizedString("my_cards", comment: "My Cards navigation title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingScanner = true
                        }) {
                            Label(NSLocalizedString("scan_card", comment: "Scan card menu item"), systemImage: "camera.viewfinder")
                        }

                        Button(action: {
                            showingManualEntry = true
                        }) {
                            Label(NSLocalizedString("add_manually", comment: "Add manually menu item"), systemImage: "keyboard")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.appPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                // TODO: Implement scanner view
                Text("Scanner View - Coming Soon")
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showingManualEntry) {
                // TODO: Implement manual entry view
                Text("Manual Entry View - Coming Soon")
                    .presentationDetents([.large])
            }
        }
    }

    private var cardListView: some View {
        List {
            ForEach(storageService.cards) { card in
                CardRowView(card: card)
                    .listRowBackground(Color.appBackground)
            }
            .onDelete { indexSet in
                // TODO: Implement delete functionality
                print("Delete cards at indices: \(indexSet)")
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.appBackground)
        .scrollContentBackground(.hidden)
    }
}

struct CardRowView: View {
    let card: Card

    var body: some View {
        HStack(spacing: 16) {
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

                Text(card.barcodeType.displayName)
                    .font(.caption)
                    .foregroundColor(.appLightGray)

                if let expiryInfo = card.expiryInfo {
                    Text(expiryInfo)
                        .font(.caption)
                        .foregroundColor(card.isExpired ? .red : .appGreen)
                }
            }

            Spacer()

            // Status indicators
            if card.isExpired {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            } else if card.oneTime && card.usedAt != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.appGreen)
                    .font(.system(size: 16))
            }
        }
        .padding(.vertical, 8)
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

extension BarcodeType {
    var displayName: String {
        switch self {
        case .qr:
            return "QR Code"
        case .code128:
            return "Code 128"
        case .pdf417:
            return "PDF417"
        case .aztec:
            return "Aztec"
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
}

#Preview {
    CardListView()
        .environmentObject(StorageService(keychainService: KeychainService()))
}
