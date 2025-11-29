import SwiftUI

struct LocationCardSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationCardService: LocationCardService
    @State private var selectedCard: Card?
    @State private var rememberPreference = true
    @State private var navigateToCard: Card?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                if locationCardService.cardsAtCurrentLocation.isEmpty {
                    emptyStateView
                } else {
                    cardSelectorContent
                }
            }
            .navigationTitle("Cards Near You")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
            .navigationDestination(item: $navigateToCard) { card in
                CardDetailView(card: card)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 64))
                .foregroundColor(.appLightGray)

            Text("No Cards Nearby")
                .font(.title2)
                .foregroundColor(.appBlue)

            Text("There are no cards available at your current location. Add cards to your wallet to see them here.")
                .font(.body)
                .foregroundColor(.appLightGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardSelectorContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Group cards by network
                let groups = locationCardService.getCardsGroupedByNetwork()

                ForEach(groups) { group in
                    networkSection(group: group)
                }

                // Open Selected Card button
                if selectedCard != nil {
                    VStack(spacing: 12) {
                        Toggle(isOn: $rememberPreference) {
                            Text("Remember my preference")
                                .font(.subheadline)
                                .foregroundColor(.appBlue)
                        }
                        .tint(.appPrimary)
                        .padding(.horizontal, 16)

                        Button(action: openSelectedCard) {
                            Text("Open Selected Card")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.appPrimary)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(.top, 16)
        }
    }

    private func networkSection(group: NetworkGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Network header
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.appPrimary)
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.network.name)
                        .font(.headline)
                        .foregroundColor(.appBlue)

                    Text("\(group.network.distanceText) • \(group.network.locationCount) locations")
                        .font(.caption)
                        .foregroundColor(.appLightGray)
                }

                Spacer()
            }
            .padding(.horizontal, 16)

            // Cards for this network
            VStack(spacing: 8) {
                ForEach(group.cards) { card in
                    Button {
                        selectCard(card, for: group.network.id)
                    } label: {
                        NetworkCardRowView(
                            card: card,
                            isSelected: selectedCard?.id == card.id,
                            showDistance: false
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)

            if group.id != locationCardService.getCardsGroupedByNetwork().last?.id {
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
    }

    private func selectCard(_ card: Card, for networkId: String) {
        selectedCard = card

        // Save preference if toggled on
        if rememberPreference {
            locationCardService.setPreferredCard(card, for: networkId)
        }
    }

    private func openSelectedCard() {
        guard let card = selectedCard else { return }
        navigateToCard = card
    }
}

// MARK: - Preview

#Preview {
    let service = LocationCardService()

    // Mock data
    let mockCard1 = Card(
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
    )

    let mockCard2 = Card(
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
    )

    let mockCard3 = Card(
        id: "3",
        userId: "user1",
        name: "Target RedCard",
        barcodeType: .code128,
        payload: "555666777",
        tags: [],
        networkIds: ["target"],
        validFrom: nil,
        validTo: nil,
        oneTime: false,
        usedAt: nil,
        metadata: [:],
        createdAt: Date(),
        updatedAt: Date()
    )

    return LocationCardSelectorView(locationCardService: service)
}
