import Foundation
import CoreLocation
import Combine

/// Service for managing location-based card discovery and selection
@MainActor
class LocationCardService: ObservableObject {
    static let shared = LocationCardService()

    @Published private(set) var cardsAtCurrentLocation: [Card] = []
    @Published private(set) var nearbyNetworks: [NetworkInfo] = []
    @Published private(set) var isNearLocation = false
    @Published private(set) var currentLocation: CLLocation?

    private let storageService: StorageService
    private let locationDiscoveryService: LocationDiscoveryService
    private var cancellables = Set<AnyCancellable>()

    // Distance threshold for "nearby" (in meters)
    private let nearbyThreshold: CLLocationDistance = 500 // 500m = ~0.3 miles

    init(
        storageService: StorageService = StorageService(),
        locationDiscoveryService: LocationDiscoveryService = LocationDiscoveryService()
    ) {
        self.storageService = storageService
        self.locationDiscoveryService = locationDiscoveryService
    }

    // MARK: - Location Updates

    /// Update current location and refresh nearby cards
    func updateLocation(_ location: CLLocation) async {
        currentLocation = location
        await refreshNearbyCards(at: location)
    }

    /// Refresh list of cards available at current location
    private func refreshNearbyCards(at location: CLLocation) async {
        do {
            // Query API for networks within radius
            let response = try await locationDiscoveryService.suggestNetworks(
                location: location.coordinate
            )

            // Extract network IDs from suggestions within threshold
            let nearbyNetworkIds = response.suggestions
                .filter { suggestion in
                    // Check if any sample location is within threshold
                    suggestion.sampleLocations.contains { sample in
                        let sampleLocation = CLLocation(
                            latitude: sample.lat,
                            longitude: sample.lon
                        )
                        return location.distance(from: sampleLocation) <= nearbyThreshold
                    }
                }
                .map { $0.id }

            // Store network info for UI display
            nearbyNetworks = response.suggestions
                .filter { nearbyNetworkIds.contains($0.id) }
                .map { suggestion in
                    let closestLocation = suggestion.sampleLocations
                        .map { sample -> (sample: LocationDiscoveryService.NetworkSuggestionResponse.SampleLocation, distance: CLLocationDistance) in
                            let sampleLocation = CLLocation(latitude: sample.lat, longitude: sample.lon)
                            return (sample, location.distance(from: sampleLocation))
                        }
                        .sorted { $0.distance < $1.distance }
                        .first

                    return NetworkInfo(
                        id: suggestion.id,
                        name: suggestion.name,
                        category: suggestion.category,
                        logoUrl: suggestion.logoUrl,
                        distance: closestLocation?.distance ?? 0,
                        locationCount: suggestion.locationCount
                    )
                }
                .sorted { $0.distance < $1.distance }

            // Filter local cards matching these networks
            let matchingCards = storageService.cards.filter { card in
                !card.networkIds.isEmpty &&
                card.networkIds.contains(where: nearbyNetworkIds.contains)
            }

            cardsAtCurrentLocation = matchingCards
            isNearLocation = !matchingCards.isEmpty

            print("✅ Found \(matchingCards.count) cards for \(nearbyNetworks.count) nearby networks")

        } catch {
            print("❌ Failed to refresh nearby cards: \(error)")
            cardsAtCurrentLocation = []
            nearbyNetworks = []
            isNearLocation = false
        }
    }

    // MARK: - Card Filtering

    /// Get all cards valid for a specific network
    func getCardsForNetwork(networkId: String) -> [Card] {
        storageService.cards.filter { card in
            card.networkIds.contains(networkId)
        }
    }

    /// Get cards grouped by network
    func getCardsGroupedByNetwork() -> [NetworkGroup] {
        var groups: [NetworkGroup] = []

        for network in nearbyNetworks {
            let cards = getCardsForNetwork(networkId: network.id)
            if !cards.isEmpty {
                groups.append(NetworkGroup(
                    network: network,
                    cards: cards,
                    preferredCard: getPreferredCard(for: network.id, from: cards)
                ))
            }
        }

        return groups.sorted { $0.network.distance < $1.network.distance }
    }

    // MARK: - Preferences

    /// Get user's preferred card for a network
    func getPreferredCard(for networkId: String, from cards: [Card]) -> Card? {
        // Check for explicitly saved preference
        if let preferred = cards.first(where: {
            $0.metadata["preferredForNetwork_\(networkId)"] == "true"
        }) {
            return preferred
        }

        // Fall back to smart selection
        return suggestCard(for: networkId, from: cards)
    }

    /// Set user's preferred card for a network
    func setPreferredCard(_ card: Card, for networkId: String) {
        var updatedCard = card

        // Clear preference from other cards for this network
        let otherCards = getCardsForNetwork(networkId: networkId)
            .filter { $0.id != card.id }

        for var otherCard in otherCards {
            otherCard.metadata.removeValue(forKey: "preferredForNetwork_\(networkId)")
            storageService.updateCard(otherCard)
        }

        // Set preference on selected card
        updatedCard.metadata["preferredForNetwork_\(networkId)"] = "true"
        updatedCard.metadata["lastUsedAt_\(networkId)"] = ISO8601DateFormatter().string(from: Date())
        storageService.updateCard(updatedCard)

        print("✅ Set preferred card '\(card.name)' for network \(networkId)")
    }

    /// Smart card suggestion based on heuristics
    private func suggestCard(for networkId: String, from cards: [Card]) -> Card? {
        guard !cards.isEmpty else { return nil }

        // Priority 1: Most recently used at this network
        let cardsWithUsage = cards.compactMap { card -> (Card, Date)? in
            guard let dateString = card.metadata["lastUsedAt_\(networkId)"],
                  let date = ISO8601DateFormatter().date(from: dateString) else {
                return nil
            }
            return (card, date)
        }
        .sorted { $0.1 > $1.1 }

        if let mostRecent = cardsWithUsage.first {
            return mostRecent.0
        }

        // Priority 2: Non-expired cards
        let nonExpired = cards.filter { !$0.isExpired }
        if !nonExpired.isEmpty {
            return nonExpired.first
        }

        // Priority 3: First alphabetically
        return cards.sorted { $0.name < $1.name }.first
    }

    // MARK: - Manual Search

    /// Search for cards by location name (fallback when location services unavailable)
    func searchCardsByLocation(query: String) -> [Card] {
        let lowercasedQuery = query.lowercased()
        return storageService.cards.filter { card in
            card.name.lowercased().contains(lowercasedQuery) ||
            card.tags.contains(where: { $0.lowercased().contains(lowercasedQuery) })
        }
    }
}

// MARK: - Supporting Types

struct NetworkInfo: Identifiable {
    let id: String
    let name: String
    let category: String
    let logoUrl: String?
    let distance: CLLocationDistance
    let locationCount: Int

    var distanceText: String {
        let miles = distance / 1609.34 // Convert meters to miles
        if miles < 0.1 {
            return "< 0.1 mi"
        } else if miles < 1 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
}

struct NetworkGroup: Identifiable {
    let network: NetworkInfo
    let cards: [Card]
    let preferredCard: Card?

    var id: String { network.id }
}
