import Foundation

/// Represents a chain/network of locations (e.g., Costco, library system)
struct Network: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var canonicalNames: [String]
    var category: NetworkCategory
    var isLargeArea: Bool
    var defaultRadiusMeters: Double
    var tags: [String]
    var locationCount: Int?

    enum NetworkCategory: String, Codable, CaseIterable {
        case grocery
        case retail
        case library
        case entertainment
        case oneTime = "one-time"
        case other

        var displayName: String {
            switch self {
            case .grocery: return "Grocery"
            case .retail: return "Retail"
            case .library: return "Library"
            case .entertainment: return "Entertainment"
            case .oneTime: return "One-Time"
            case .other: return "Other"
            }
        }

        var icon: String {
            switch self {
            case .grocery: return "cart.fill"
            case .retail: return "bag.fill"
            case .library: return "book.fill"
            case .entertainment: return "ticket.fill"
            case .oneTime: return "clock.fill"
            case .other: return "questionmark.circle.fill"
            }
        }
    }

    /// Check if a name matches this network (fuzzy matching)
    func matches(_ query: String) -> Bool {
        let queryLower = query.lowercased()
        if name.lowercased().contains(queryLower) {
            return true
        }
        return canonicalNames.contains { $0.lowercased().contains(queryLower) }
    }
}
