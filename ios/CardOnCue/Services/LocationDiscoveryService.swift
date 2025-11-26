import Foundation
import CoreLocation

/// Service for discovering and managing locations for cards
class LocationDiscoveryService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// Get all available locations for a card
    func getLocationsForCard(cardId: String) async throws -> CardLocationsResponse {
        let endpoint = "/api/v1/cards/\(cardId)/locations"
        let data: [String: Any] = try await apiClient.get(endpoint: endpoint)
        return try CardLocationsResponse(from: data)
    }

    /// Enable locations for a card
    func enableLocations(cardId: String, locationIds: [String]) async throws {
        let endpoint = "/api/v1/cards/\(cardId)/locations"
        let body: [String: Any] = [
            "locationIds": locationIds,
            "action": "enable"
        ]
        _ = try await apiClient.post(endpoint: endpoint, body: body)
    }

    /// Disable locations for a card
    func disableLocations(cardId: String, locationIds: [String]) async throws {
        let endpoint = "/api/v1/cards/\(cardId)/locations"
        let body: [String: Any] = [
            "locationIds": locationIds,
            "action": "disable"
        ]
        _ = try await apiClient.post(endpoint: endpoint, body: body)
    }

    /// Suggest networks based on card information
    func suggestNetworks(
        cardName: String? = nil,
        location: CLLocationCoordinate2D? = nil,
        category: String? = nil
    ) async throws -> NetworkSuggestionResponse {
        let endpoint = "/api/v1/networks/suggest"

        var body: [String: Any] = [:]

        if let cardName = cardName {
            body["cardName"] = cardName
        }

        if let location = location {
            body["location"] = [
                "lat": location.latitude,
                "lon": location.longitude
            ]
        }

        if let category = category {
            body["category"] = category
        }

        let data: [String: Any] = try await apiClient.post(endpoint: endpoint, body: body)
        return try NetworkSuggestionResponse(from: data)
    }

    /// Suggest network based on current location
    func suggestNetworkNearby(cardName: String) async throws -> NetworkSuggestionResponse {
        let location = await LocationService.shared.getCurrentLocation()
        return try await suggestNetworks(
            cardName: cardName,
            location: location?.coordinate
        )
    }
}

// MARK: - Models

struct CardLocationsResponse: Codable {
    let card: CardInfo
    let networks: [Network]
    let locations: [LocationInfo]
    let total: Int
    let enabled: Int

    struct CardInfo: Codable {
        let id: String
        let name: String
    }

    struct Network: Codable {
        let id: String
        let name: String
        let category: String
        let logoUrl: String?
    }

    struct LocationInfo: Codable {
        let id: String
        let name: String
        let address: String?
        let city: String?
        let state: String?
        let country: String?
        let postalCode: String?
        let phone: String?
        let website: String?
        let lat: Double
        let lon: Double
        let networkId: String
        let networkName: String
        let networkCategory: String
        let enabled: Bool

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    init(from dict: [String: Any]) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: dict)
        self = try JSONDecoder().decode(CardLocationsResponse.self, from: jsonData)
    }
}

struct NetworkSuggestionResponse: Codable {
    let suggestions: [NetworkSuggestion]
    let query: Query

    struct NetworkSuggestion: Codable {
        let id: String
        let name: String
        let category: String
        let logoUrl: String?
        let description: String?
        let locationCount: Int
        let sampleLocations: [SampleLocation]
        let matchScore: Double
    }

    struct SampleLocation: Codable {
        let id: String
        let name: String
        let city: String?
        let state: String?
        let lat: Double
        let lon: Double

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    struct Query: Codable {
        let cardName: String?
        let location: LocationQuery?
        let category: String?
    }

    struct LocationQuery: Codable {
        let lat: Double
        let lon: Double
    }

    init(from dict: [String: Any]) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: dict)
        self = try JSONDecoder().decode(NetworkSuggestionResponse.self, from: jsonData)
    }
}
