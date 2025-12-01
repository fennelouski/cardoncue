import Foundation

enum CardLocationError: Error {
    case invalidURL
    case invalidResponse
    case uploadFailed
    case networkError(Error)
}

actor CardLocationService {
    static let shared = CardLocationService()

    private let baseURL = "https://www.cardoncue.com/api/v1"

    private init() {}

    func addLocation(
        for cardId: String,
        userId: String,
        locationName: String,
        address: String? = nil,
        city: String? = nil,
        state: String? = nil,
        country: String? = nil,
        postalCode: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        notes: String? = nil
    ) async throws -> CardLocation {
        let endpoint = "\(baseURL)/cards/\(cardId)/locations"

        guard let url = URL(string: endpoint) else {
            throw CardLocationError.invalidURL
        }

        let request = CardLocationRequest(
            userId: userId,
            locationName: locationName,
            address: address,
            city: city,
            state: state,
            country: country,
            postalCode: postalCode,
            latitude: latitude,
            longitude: longitude,
            notes: notes
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CardLocationError.invalidResponse
        }

        struct LocationResponse: Codable {
            let location: CardLocation
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let locationResponse = try decoder.decode(LocationResponse.self, from: data)
        return locationResponse.location
    }

    func getLocations(for cardId: String, userId: String) async throws -> [CardLocation] {
        let endpoint = "\(baseURL)/cards/\(cardId)/locations?userId=\(userId)"

        guard let url = URL(string: endpoint) else {
            throw CardLocationError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CardLocationError.invalidResponse
        }

        struct LocationsResponse: Codable {
            let locations: [CardLocation]
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let locationsResponse = try decoder.decode(LocationsResponse.self, from: data)
        return locationsResponse.locations
    }
}
