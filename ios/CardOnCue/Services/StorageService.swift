import Foundation
import Combine

class StorageService: ObservableObject {
    @Published private(set) var cards: [Card] = []
    @Published private(set) var deletedCards: [DeletedCard] = []

    private let keychainService: KeychainService
    private let cardsKey = "cards"
    private let deletedCardsKey = "deletedCards"

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
        loadCards()
        loadDeletedCards()
        cleanupOldDeletedCards()
    }

    // MARK: - CRUD Operations

    func addCard(_ card: Card) {
        cards.append(card)
        saveCards()
    }

    func updateCard(_ card: Card) {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
            saveCards()
        }
    }

    func deleteCard(_ card: Card) {
        cards.removeAll { $0.id == card.id }
        let deletedCard = DeletedCard(id: card.id, card: card, deletedAt: Date())
        deletedCards.append(deletedCard)
        saveCards()
        saveDeletedCards()
    }

    func deleteCards(at offsets: IndexSet) {
        let cardsToDelete = offsets.map { cards[$0] }
        cards.remove(atOffsets: offsets)

        for card in cardsToDelete {
            let deletedCard = DeletedCard(id: card.id, card: card, deletedAt: Date())
            deletedCards.append(deletedCard)
        }

        saveCards()
        saveDeletedCards()
    }

    func getCard(by id: String) -> Card? {
        cards.first { $0.id == id }
    }

    func deleteAllCards() {
        cards.removeAll()
        saveCards()
    }

    // MARK: - Persistence

    private func loadCards() {
        do {
            cards = try keychainService.load(for: cardsKey, as: [Card].self)
        } catch KeychainService.KeychainError.itemNotFound {
            cards = []
        } catch {
            print("Error loading cards: \(error)")
            cards = []
        }
    }

    private func saveCards() {
        do {
            try keychainService.save(cards, for: cardsKey)
        } catch {
            print("Error saving cards: \(error)")
        }
    }

    // MARK: - Search & Filter

    func searchCards(query: String) -> [Card] {
        guard !query.isEmpty else { return cards }

        let lowercasedQuery = query.lowercased()
        return cards.filter { card in
            card.name.lowercased().contains(lowercasedQuery) ||
            card.tags.contains(where: { $0.lowercased().contains(lowercasedQuery) })
        }
    }

    func filterCards(by tag: String) -> [Card] {
        cards.filter { $0.tags.contains(tag) }
    }

    func filterCards(by barcodeType: BarcodeType) -> [Card] {
        cards.filter { $0.barcodeType == barcodeType }
    }

    func getExpiredCards() -> [Card] {
        cards.filter { $0.isExpired }
    }

    func getExpiringCards(withinDays days: Int) -> [Card] {
        cards.filter { card in
            guard let daysUntil = card.daysUntilExpiration else { return false }
            return daysUntil > 0 && daysUntil <= days
        }
    }

    // MARK: - Statistics

    var totalCards: Int {
        cards.count
    }

    var expiredCardsCount: Int {
        cards.filter { $0.isExpired }.count
    }

    var oneTimeCardsCount: Int {
        cards.filter { $0.oneTime }.count
    }

    var usedCardsCount: Int {
        cards.filter { $0.usedAt != nil }.count
    }

    // MARK: - Sorting

    func sortedCards(by option: SortOption) -> [Card] {
        switch option {
        case .nameAscending:
            return cards.sorted { $0.name < $1.name }
        case .nameDescending:
            return cards.sorted { $0.name > $1.name }
        case .dateCreatedNewest:
            return cards.sorted { $0.createdAt > $1.createdAt }
        case .dateCreatedOldest:
            return cards.sorted { $0.createdAt < $1.createdAt }
        case .expirationSoonest:
            return cards.sorted { (card1, card2) in
                guard let exp1 = card1.validTo, let exp2 = card2.validTo else {
                    return card1.validTo != nil
                }
                return exp1 < exp2
            }
        }
    }

    enum SortOption {
        case nameAscending
        case nameDescending
        case dateCreatedNewest
        case dateCreatedOldest
        case expirationSoonest
    }

    // MARK: - Trash Management

    func restoreCard(_ deletedCard: DeletedCard) {
        deletedCards.removeAll { $0.id == deletedCard.id }
        cards.append(deletedCard.card)
        saveCards()
        saveDeletedCards()
    }

    func permanentlyDeleteCard(_ deletedCard: DeletedCard) {
        deletedCards.removeAll { $0.id == deletedCard.id }
        saveDeletedCards()
    }

    func emptyTrash() {
        deletedCards.removeAll()
        saveDeletedCards()
    }

    private func cleanupOldDeletedCards() {
        deletedCards.removeAll { $0.isPermanentlyDeletable }
        saveDeletedCards()
    }

    var deletedCardsCount: Int {
        deletedCards.count
    }

    // MARK: - Deleted Cards Persistence

    private func loadDeletedCards() {
        do {
            deletedCards = try keychainService.load(for: deletedCardsKey, as: [DeletedCard].self)
        } catch KeychainService.KeychainError.itemNotFound {
            deletedCards = []
        } catch {
            print("Error loading deleted cards: \(error)")
            deletedCards = []
        }
    }

    private func saveDeletedCards() {
        do {
            try keychainService.save(deletedCards, for: deletedCardsKey)
        } catch {
            print("Error saving deleted cards: \(error)")
        }
    }
}
