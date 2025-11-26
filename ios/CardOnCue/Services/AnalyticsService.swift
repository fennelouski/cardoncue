import Foundation

/// Service for tracking analytics events
class AnalyticsService {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    /// Track an analytics event
    func track(
        event: AnalyticsEvent,
        cardId: String? = nil,
        locationId: String? = nil,
        metadata: [String: Any]? = nil
    ) async throws {
        let endpoint = "/api/v1/analytics/track"

        var body: [String: Any] = [
            "event": event.rawValue
        ]

        if let cardId = cardId {
            body["cardId"] = cardId
        }

        if let locationId = locationId {
            body["locationId"] = locationId
        }

        if let metadata = metadata {
            body["metadata"] = metadata
        }

        // Add session ID for unauthenticated tracking
        body["sessionId"] = await getSessionId()

        _ = try await apiClient.post(endpoint: endpoint, body: body)
    }

    /// Track card viewed event
    func trackCardViewed(cardId: String) async {
        try? await track(event: .cardViewed, cardId: cardId)
    }

    /// Track card scanned event
    func trackCardScanned(cardId: String, method: String = "auto") async {
        try? await track(
            event: .cardScanned,
            cardId: cardId,
            metadata: ["method": method]
        )
    }

    /// Track location entered event
    func trackLocationEntered(locationId: String, cardId: String? = nil) async {
        try? await track(
            event: .locationEntered,
            cardId: cardId,
            locationId: locationId
        )
    }

    /// Track notification received
    func trackNotificationReceived(cardId: String?, locationId: String?) async {
        try? await track(
            event: .notificationReceived,
            cardId: cardId,
            locationId: locationId
        )
    }

    /// Fetch analytics dashboard data
    func fetchDashboard(period: AnalyticsPeriod = .thirtyDays) async throws -> AnalyticsDashboard {
        let endpoint = "/api/v1/analytics/dashboard?period=\(period.rawValue)"
        let data: [String: Any] = try await apiClient.get(endpoint: endpoint)
        return try AnalyticsDashboard(from: data)
    }

    // MARK: - Private Helpers

    private func getSessionId() async -> String {
        // Try to get user ID from Keychain, otherwise use device identifier
        if let userId = KeychainService.shared.getUserId() {
            return userId
        }
        return await UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
}

// MARK: - Models

enum AnalyticsEvent: String {
    case cardViewed = "card_viewed"
    case cardScanned = "card_scanned"
    case cardAdded = "card_added"
    case cardEdited = "card_edited"
    case cardDeleted = "card_deleted"
    case locationEntered = "location_entered"
    case locationExited = "location_exited"
    case notificationReceived = "notification_received"
    case notificationOpened = "notification_opened"
    case searchPerformed = "search_performed"
    case networkDiscovered = "network_discovered"
}

enum AnalyticsPeriod: String {
    case sevenDays = "7d"
    case thirtyDays = "30d"
    case ninetyDays = "90d"
    case all = "all"
}

struct AnalyticsDashboard: Codable {
    let period: String
    let summary: AnalyticsSummary
    let mostViewedCards: [CardUsage]
    let eventCounts: [String: Int]
    let dailyActivity: [DailyActivity]
    let topLocations: [LocationUsage]
    let peakHours: [PeakHour]

    struct AnalyticsSummary: Codable {
        let totalCards: Int
        let totalLocations: Int
        let totalEvents: Int
    }

    struct CardUsage: Codable {
        let id: String
        let name: String
        let cardType: String
        let viewCount: Int
        let recentEvents: Int
        let lastViewed: String?
    }

    struct DailyActivity: Codable {
        let date: String
        let eventCount: Int
        let uniqueCards: Int
    }

    struct LocationUsage: Codable {
        let id: String
        let name: String
        let city: String?
        let state: String?
        let networkName: String
        let visitCount: Int
    }

    struct PeakHour: Codable {
        let hour: Int
        let eventCount: Int
    }

    init(from dict: [String: Any]) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: dict)
        self = try JSONDecoder().decode(AnalyticsDashboard.self, from: jsonData)
    }
}
