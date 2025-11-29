import Foundation

struct GiftCardBalanceHistory: Identifiable, Codable, Hashable {
    let id: String
    let cardId: String
    let balance: Decimal
    let currency: String
    let notes: String?
    let createdAt: Date

    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSDecimalNumber(decimal: balance)) ?? "\(balance)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case balance
        case currency
        case notes
        case createdAt = "created_at"
    }
}
