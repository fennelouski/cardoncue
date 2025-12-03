import SwiftUI

struct CardListView: View {
    @EnvironmentObject var storageService: StorageService
    @StateObject private var locationCardService = LocationCardService.shared
    @State private var showingScanner = false
    @State private var showingManualEntry = false
    @State private var showingDeleteAlert = false
    @State private var showingLocationSelector = false
    @State private var indexSetToDelete: IndexSet?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    // Determine threshold based on device type
    private var cardThresholdForPrompt: Int {
        // iPad: show until 5 cards, iPhone: show until 3 cards
        return horizontalSizeClass == .regular ? 5 : 3
    }

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
                // Only show toolbar button when user has enough cards
                if storageService.cards.count >= cardThresholdForPrompt {
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
            }
            .sheet(isPresented: $showingScanner) {
                SmartCardScannerView()
                    .environmentObject(storageService)
            }
            .sheet(isPresented: $showingManualEntry) {
                // TODO: Implement manual entry view
                Text("Manual Entry View - Coming Soon")
                    .presentationDetents([.large])
            }
            .alert("Delete Card", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    indexSetToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let indexSet = indexSetToDelete {
                        storageService.deleteCards(at: indexSet)
                        indexSetToDelete = nil
                    }
                }
            } message: {
                Text("This card will be moved to trash and can be restored within 7 days.")
            }
            .sheet(isPresented: $showingLocationSelector) {
                LocationCardSelectorView(locationCardService: locationCardService)
            }
        }
    }

    private var cardListView: some View {
        List {
            // Location banner (only show if cards nearby)
            if locationCardService.isNearLocation && !locationCardService.cardsAtCurrentLocation.isEmpty {
                locationBanner
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            ForEach(storageService.cards) { card in
                NavigationLink(destination: CardDetailView(card: card)) {
                    CardRowView(card: card)
                }
                .listRowBackground(Color.appBackground)
            }
            .onDelete { indexSet in
                indexSetToDelete = indexSet
                showingDeleteAlert = true
            }

            // Show prominent "Add Card" section when user has few cards
            if storageService.cards.count < cardThresholdForPrompt {
                addCardPrompt
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.appBackground)
        .scrollContentBackground(.hidden)
    }

    private var locationBanner: some View {
        Button {
            showingLocationSelector = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.appPrimary)
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(locationCardService.cardsAtCurrentLocation.count) card\(locationCardService.cardsAtCurrentLocation.count == 1 ? "" : "s") available nearby")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.appBlue)

                    if let firstNetwork = locationCardService.nearbyNetworks.first {
                        Text(firstNetwork.name + (locationCardService.nearbyNetworks.count > 1 ? " and \(locationCardService.nearbyNetworks.count - 1) more" : ""))
                            .font(.caption)
                            .foregroundColor(.appLightGray)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.appLightGray)
                    .font(.system(size: 14))
            }
            .padding(12)
            .background(Color.appPrimary.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appPrimary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var addCardPrompt: some View {
        VStack(spacing: 24) {
            // Circular icon illustration (similar to EmptyStateView)
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "creditcard.viewfinder")
                    .font(.system(size: 40))
                    .foregroundColor(.appPrimary)
            }

            // Content
            VStack(spacing: 12) {
                Text("Add Another Card")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.appBlue)

                Text("Scan or enter your gift card details")
                    .font(.body)
                    .foregroundColor(.appGreen)
                    .multilineTextAlignment(.center)
            }

            // Action buttons (matching EmptyStateView style)
            VStack(spacing: 12) {
                Button(action: {
                    showingScanner = true
                }) {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                            .font(.headline)
                        Text(NSLocalizedString("scan_card", comment: "Scan card menu item"))
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.appPrimary)
                    .cornerRadius(12)
                }

                Button(action: {
                    showingManualEntry = true
                }) {
                    Text(NSLocalizedString("add_manually", comment: "Add manually button"))
                        .font(.subheadline)
                        .foregroundColor(.appBlue)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
}

struct CardRowView: View {
    let card: Card

    var body: some View {
        HStack(spacing: 16) {
            // Card icon
            CardIconView(card: card, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(.appBlue)

                if let personName = card.personName, !personName.isEmpty {
                    Text(personName)
                        .font(.caption)
                        .foregroundColor(.appLightGray)
                } else if let locationName = card.locationName, !locationName.isEmpty {
                    Text(locationName)
                        .font(.caption)
                        .foregroundColor(.appLightGray)
                }

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
