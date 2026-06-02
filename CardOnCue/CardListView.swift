import SwiftUI
import SwiftData

struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CardModel> { card in
        card.archivedAt == nil
    }, sort: \CardModel.createdAt, order: .reverse)
    private var cards: [CardModel]

    @StateObject private var cameraPermission = CameraPermissionManager()
    @State private var showingAddCardView = false
    @State private var showingArchivedCards = false
    
    private var isCameraAvailable: Bool {
        cameraPermission.isCameraAvailable && cameraPermission.permissionStatus != .unavailable
    }

    // Computed property for grouped cards.
    // Cards are grouped by a stable place/brand key (network id when known,
    // else normalized brand) so the same place groups across cardholders.
    private var groupedCards: [(key: String, brand: String, cards: [CardModel])] {
        let grouped = Dictionary(grouping: cards) { $0.groupKey }

        var groups: [(key: String, brand: String, cards: [CardModel])] = grouped.map { (key, cards) in
            let sortedCards = cards.sorted { $0.createdAt > $1.createdAt }
            // Display title: prefer a non-"Other" brand name from the group.
            let title = sortedCards.first(where: { $0.brandName != "Other" })?.brandName
                ?? sortedCards.first?.brandName
                ?? "Other"
            return (key, title, sortedCards)
        }

        // Sort groups alphabetically by title, with "Other" last.
        groups.sort { lhs, rhs in
            if lhs.brand == "Other" { return false }
            if rhs.brand == "Other" { return true }
            return lhs.brand.localizedCaseInsensitiveCompare(rhs.brand) == .orderedAscending
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    EmptyStateView(
                        onAddCard: {
                            showingAddCardView = true
                        },
                        canScan: isCameraAvailable && cameraPermission.permissionStatus != .denied
                    )
                } else {
                    cardListView
                        .navigationTitle(NSLocalizedString("my_cards", comment: "My Cards navigation title"))
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showingAddCardView = true
                                }) {
                                    Image(systemName: "plus")
                                        .foregroundColor(.appPrimary)
                                }
                            }
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: {
                                    showingArchivedCards = true
                                }) {
                                    Image(systemName: "archivebox")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingAddCardView) {
                AddCardSwipeableView(
                    canScan: isCameraAvailable && cameraPermission.permissionStatus != .denied
                )
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingArchivedCards) {
                ArchivedCardsView()
            }
        }
        .onAppear {
            GeofenceManager.shared.syncCardsToWatch()
        }
        .onChange(of: cards.map(\.updatedAt)) { _ in
            GeofenceManager.shared.syncCardsToWatch()
        }
    }

    private var cardListView: some View {
        List {
            ForEach(groupedCards, id: \.key) { group in
                Section(header: BrandSectionHeader(
                    brandName: group.brand,
                    cardCount: group.cards.count
                )) {
                    ForEach(group.cards) { card in
                        NavigationLink(destination: CardDetailView(card: card)) {
                            CardRowView(card: card)
                        }
                        .listRowBackground(Color.appBackground)
                    }
                    .onDelete { offsets in
                        deleteCards(in: group.cards, at: offsets)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.appBackground)
        .scrollContentBackground(.hidden)
    }

    private func deleteCards(in groupCards: [CardModel], at offsets: IndexSet) {
        for index in offsets {
            let card = groupCards[index]
            // Soft delete - set archivedAt instead of actually deleting
            card.archivedAt = Date()
            card.updatedAt = Date()
        }
        PersistenceHelper.save(modelContext, label: "CardListView.deleteCards")
    }

}

struct CardRowView: View {
    let card: CardModel

    @State private var brandLogo: UIImage? = nil
    @State private var isLoadingLogo = true

    var body: some View {
        HStack(spacing: 16) {
            // Brand logo or card icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appLightGray.opacity(0.2))
                    .frame(width: 50, height: 50)  // Increased from 35 to 50

                if isLoadingLogo {
                    ProgressView()
                        .frame(width: 50, height: 50)
                } else if let logo = brandLogo {
                    Image(uiImage: logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .cornerRadius(8)
                } else {
                    // Fallback to existing icon
                    CardIconDisplay(
                        icon: card.getIcon() ?? CardIcon.sfSymbol(barcodeIcon(for: card.barcodeType)),
                        size: 35
                    )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(.appBlue)

                if let cardholder = card.cardholderName {
                    Text(cardholder)
                        .font(.caption)
                        .foregroundColor(.appLightGray)
                } else if let locationName = card.locationName, !locationName.isEmpty {
                    Text(locationName)
                        .font(.caption)
                        .foregroundColor(.appLightGray)
                } else {
                    Text(card.barcodeType.displayName)
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
        .task {
            await loadBrandLogo()
        }
    }

    private func loadBrandLogo() async {
        let logo = await BrandLogoService.shared.fetchLogo(for: card.brandName)
        await MainActor.run {
            brandLogo = logo
            isLoadingLogo = false
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

// MARK: - Brand Section Header
struct BrandSectionHeader: View {
    let brandName: String
    let cardCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(brandName)
                .font(.headline)
                .foregroundColor(.primary)

            Text("(\(cardCount))")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CardModel.self, configurations: config)

        return CardListView()
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
