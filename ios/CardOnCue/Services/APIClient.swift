import Foundation

/// HTTP client for CardOnCue API
class APIClient {
    private let baseURL: URL
    private let keychainService: KeychainService
    private let session: URLSession

    enum APIError: LocalizedError {
        case invalidURL
        case noData
        case decodingFailed
        case unauthorized
        case serverError(Int)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .noData:
                return "No data received from server"
            case .decodingFailed:
                return "Failed to decode server response"
            case .unauthorized:
                return "Unauthorized. Please sign in again."
            case .serverError(let code):
                return "Server error (HTTP \(code))"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }

    init(baseURL: String, keychainService: KeychainService) {
        self.baseURL = URL(string: baseURL)!
        self.keychainService = keychainService
        self.session = URLSession.shared
    }

    // MARK: - Authentication

    func signInWithApple(identityToken: String, userIdentifier: String, email: String?, fullName: PersonNameComponents?) async throws -> AuthResponse {
        let endpoint = "/auth/apple"

        let body: [String: Any] = [
            "identity_token": identityToken,
            "user_identifier": userIdentifier,
            "email": email as Any,
            "full_name": fullName.map { ["given_name": $0.givenName, "family_name": $0.familyName] } as Any
        ]

        let response: AuthResponse = try await post(endpoint, body: body, authenticated: false)

        // Store tokens in Keychain
        try keychainService.storeAccessToken(response.accessToken)
        try keychainService.storeRefreshToken(response.refreshToken)

        return response
    }

    // MARK: - Cards

    func getCards() async throws -> [Card] {
        let endpoint = "/cards"
        let response: CardsResponse = try await get(endpoint)
        return response.cards
    }

    func createCard(_ card: EncryptedCard) async throws -> Card {
        let endpoint = "/cards"
        // TODO: Implement card creation with encryption
        fatalError("Not implemented")
    }

    // MARK: - Region Refresh

    func refreshRegions(_ request: RegionRefreshRequest) async throws -> RegionRefreshResponse {
        let endpoint = "/region-refresh"
        return try await post(endpoint, body: request)
    }

    // MARK: - Generic HTTP Methods

    private func get<T: Decodable>(_ endpoint: String, authenticated: Bool = true) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        if authenticated {
            try addAuthHeader(to: &request)
        }

        return try await performRequest(request)
    }

    private func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U, authenticated: Bool = true) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Encode body
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        if authenticated {
            try addAuthHeader(to: &request)
        }

        return try await performRequest(request)
    }

    private func post<T: Decodable>(_ endpoint: String, body: [String: Any], authenticated: Bool = true) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Encode body
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        if authenticated {
            try addAuthHeader(to: &request)
        }

        return try await performRequest(request)
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(NSError(domain: "Invalid response", code: -1))
            }

            // Handle HTTP errors
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                throw APIError.unauthorized
            default:
                throw APIError.serverError(httpResponse.statusCode)
            }

            // Decode response
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                print("❌ Decoding error: \(error)")
                print("Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw APIError.decodingFailed
            }

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func addAuthHeader(to request: inout URLRequest) throws {
        guard let token = try keychainService.getAccessToken() else {
            throw APIError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

// MARK: - Response Models

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    let user: User

    struct User: Codable {
        let id: String
        let email: String?
        let fullName: String?
        let createdAt: Date
        let preferences: Preferences

        struct Preferences: Codable {
            let syncEnabled: Bool
            let notificationRadiusMeters: Int
        }
    }
}

struct CardsResponse: Codable {
    let cards: [Card]
    let count: Int
}
