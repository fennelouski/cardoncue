import Foundation

struct GiftCardBrand: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var issuer: String
    var description: String?
    var acceptedNetworkIds: [String]
    var category: String?
    var iconUrl: String?
    var autoDiscovered: Bool
    let createdAt: Date
    var updatedAt: Date

    /// Returns a user-friendly description of where this gift card can be used
    var acceptedLocationsDescription: String {
        if acceptedNetworkIds.isEmpty {
            return "No locations available"
        } else if acceptedNetworkIds.count == 1 {
            return "Accepted at 1 merchant"
        } else {
            return "Accepted at \(acceptedNetworkIds.count) merchants"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, name, issuer, description, category
        case acceptedNetworkIds = "accepted_network_ids"
        case iconUrl = "icon_url"
        case autoDiscovered = "auto_discovered"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Card type enum for categorizing different types of cards
enum CardType: String, Codable, CaseIterable {
    case loyalty = "loyalty"
    case membership = "membership"
    case giftCard = "gift_card"
    case voucher = "voucher"
    case other = "other"

    var displayName: String {
        switch self {
        case .loyalty:
            return "Loyalty Card"
        case .membership:
            return "Membership Card"
        case .giftCard:
            return "Gift Card"
        case .voucher:
            return "Voucher"
        case .other:
            return "Other"
        }
    }

    var icon: String {
        switch self {
        case .loyalty:
            return "star.circle.fill"
        case .membership:
            return "person.crop.circle.fill"
        case .giftCard:
            return "giftcard.fill"
        case .voucher:
            return "ticket.fill"
        case .other:
            return "creditcard.fill"
        }
    }
}
