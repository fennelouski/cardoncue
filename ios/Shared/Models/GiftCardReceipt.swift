import Foundation

struct GiftCardReceipt: Identifiable, Codable, Hashable {
    let id: String
    let cardId: String
    let balanceHistoryId: String?
    let imageUrl: String
    let notes: String?
    let purchaseDate: Date?
    let createdAt: Date
    let associatedBalance: Decimal?

    var formattedPurchaseDate: String? {
        guard let purchaseDate = purchaseDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: purchaseDate)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case balanceHistoryId = "balance_history_id"
        case imageUrl = "image_url"
        case notes
        case purchaseDate = "purchase_date"
        case createdAt = "created_at"
        case associatedBalance = "associated_balance"
    }
}
