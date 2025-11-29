import Foundation

struct DeletedCard: Identifiable, Codable {
    let id: String
    let card: Card
    let deletedAt: Date

    var daysUntilPermanentDeletion: Int {
        let calendar = Calendar.current
        let expirationDate = calendar.date(byAdding: .day, value: 7, to: deletedAt) ?? deletedAt
        let days = calendar.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return max(0, days)
    }

    var isPermanentlyDeletable: Bool {
        daysUntilPermanentDeletion == 0
    }
}
