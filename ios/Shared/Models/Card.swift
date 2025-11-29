import Foundation

struct Card: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    var name: String
    var barcodeType: BarcodeType
    var payload: String
    var tags: [String]
    var networkIds: [String]
    var validFrom: Date?
    var validTo: Date?
    var oneTime: Bool
    var usedAt: Date?
    var metadata: [String: String]
    let createdAt: Date
    var updatedAt: Date
    var defaultIconUrl: String?
    var customIconUrl: String?
    var cardType: CardType
    var giftCardBrandId: String?
    var currentBalance: Decimal?
    var balanceCurrency: String?
    var balanceLastUpdated: Date?

    var isExpired: Bool {
        guard let validTo = validTo else { return false }
        return validTo < Date()
    }

    var daysUntilExpiration: Int? {
        guard let validTo = validTo else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: validTo).day
        return days
    }

    var iconUrl: String? {
        return customIconUrl ?? defaultIconUrl
    }

    var isGiftCard: Bool {
        return cardType == .giftCard
    }

    enum CodingKeys: String, CodingKey {
        case id, userId, name, barcodeType, payload, tags, networkIds
        case validFrom, validTo, oneTime, usedAt, metadata, createdAt, updatedAt
        case defaultIconUrl = "default_icon_url"
        case customIconUrl = "custom_icon_url"
        case cardType = "card_type"
        case giftCardBrandId = "gift_card_brand_id"
        case currentBalance = "current_balance"
        case balanceCurrency = "balance_currency"
        case balanceLastUpdated = "balance_last_updated"
    }
}

enum BarcodeType: String, Codable {
    case qr
    case code128
    case pdf417
    case aztec
    case ean13
    case upcA = "upc_a"
    case code39
    case itf
}
