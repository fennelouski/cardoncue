import Foundation
import UserNotifications
import WatchConnectivity
#if os(watchOS)
import WatchKit
#endif

/// Manages notifications and card display on watchOS
@MainActor
class WatchNotificationManager: NSObject, ObservableObject {
    static let shared = WatchNotificationManager()
    
    @Published private(set) var cards: [WatchCardDisplay] = []
    @Published var currentCard: WatchCardDisplay?
    
    private let persistenceKey = "watchLastDisplayedCard"
    private let cardsPersistenceKey = "watchSyncedCards"
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        configureWatchConnectivity()
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Watch notification permission granted")
            } else {
                print("⚠️ Watch notification permission denied: \(error?.localizedDescription ?? "unknown")")
            }
        }
    }
    
    /// Persist current card to UserDefaults
    func saveCurrentCard() {
        guard let card = currentCard else { return }
        
        if let encoded = try? JSONEncoder().encode(card),
           let jsonString = String(data: encoded, encoding: .utf8) {
            UserDefaults.standard.set(jsonString, forKey: persistenceKey)
        }
    }
    
    /// Restore last displayed card from UserDefaults
    func restoreLastCard() {
        guard let jsonString = UserDefaults.standard.string(forKey: persistenceKey),
              let data = jsonString.data(using: .utf8),
              let card = try? JSONDecoder().decode(WatchCardDisplay.self, from: data) else {
            return
        }
        
        currentCard = card
    }

    func saveCards() {
        guard let encoded = try? JSONEncoder().encode(cards),
              let jsonString = String(data: encoded, encoding: .utf8) else {
            return
        }
        UserDefaults.standard.set(jsonString, forKey: cardsPersistenceKey)
    }

    func restoreCards() {
        guard let jsonString = UserDefaults.standard.string(forKey: cardsPersistenceKey),
              let data = jsonString.data(using: .utf8),
              let restored = try? JSONDecoder().decode([WatchCardDisplay].self, from: data) else {
            return
        }
        cards = restored
        if currentCard == nil {
            currentCard = cards.first
        }
    }
    
    /// Clear persisted card
    func clearPersistedCard() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
        UserDefaults.standard.removeObject(forKey: cardsPersistenceKey)
    }

    func selectCard(_ card: WatchCardDisplay) {
        currentCard = card
        saveCurrentCard()
    }

    private func configureWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func mergeSyncedCards(_ syncedCards: [WatchCardDisplay]) {
        let previousCurrentId = currentCard?.id
        cards = syncedCards

        if let previousCurrentId,
           let matched = cards.first(where: { $0.id == previousCurrentId }) {
            currentCard = matched
        } else if let currentCard,
                  !cards.contains(where: { $0.id == currentCard.id }) {
            // Preserve the notification-driven card until the next sync includes it.
            cards.insert(currentCard, at: 0)
        } else {
            currentCard = cards.first
        }

        saveCards()
        saveCurrentCard()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension WatchNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
        
        // Process notification to display card
        Task { @MainActor in
            processNotification(notification)
        }
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Process notification when user taps it
        Task { @MainActor in
            processNotification(response.notification)
            completionHandler()
        }
    }
    
    private func processNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        
        // Check if this is a geofence card notification
        guard userInfo["action"] as? String == "startLiveActivity",
              let cardId = userInfo["cardId"] as? String,
              let cardName = userInfo["cardName"] as? String,
              let barcodeType = userInfo["barcodeType"] as? String,
              let payload = userInfo["payload"] as? String else {
            print("⚠️ Invalid notification payload")
            return
        }
        
        let locationName = userInfo["locationName"] as? String
        let availableCardsCount = userInfo["availableCardsCount"] as? Int ?? 1
        
        let card = WatchCardDisplay(
            cardId: cardId,
            cardName: cardName,
            barcodeType: barcodeType,
            payload: payload,
            locationName: locationName,
            availableCardsCount: availableCardsCount
        )
        
        currentCard = card
        if let existingIndex = cards.firstIndex(where: { $0.id == card.id }) {
            cards[existingIndex] = card
        } else {
            cards.insert(card, at: 0)
        }
        saveCards()
        saveCurrentCard() // Persist for next app launch
        
        // Post notification to update UI
        NotificationCenter.default.post(
            name: NSNotification.Name("WatchCardNotification"),
            object: nil,
            userInfo: ["card": card]
        )
        
        print("✅ Displaying card on watch: \(cardName)")
        
        // Haptic feedback
        #if os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #endif
    }
}

// MARK: - WatchConnectivity

extension WatchNotificationManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("⚠️ Watch WCSession activation failed: \(error.localizedDescription)")
            return
        }

        guard activationState == .activated else { return }
        if let cardsPayload = session.receivedApplicationContext["cardsPayload"] as? Data {
            Task { @MainActor in
                self.handleCardsPayload(cardsPayload)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        guard let cardsPayload = applicationContext["cardsPayload"] as? Data else { return }
        Task { @MainActor in
            self.handleCardsPayload(cardsPayload)
        }
    }

    @MainActor
    private func handleCardsPayload(_ payloadData: Data) {
        do {
            let snapshot = try JSONDecoder().decode(WatchSyncSnapshotDTO.self, from: payloadData)
            let syncedCards = snapshot.cards.map {
                WatchCardDisplay(
                    cardId: $0.id,
                    cardName: $0.cardName,
                    barcodeType: $0.barcodeType,
                    payload: $0.payload,
                    locationName: $0.locationName,
                    availableCardsCount: $0.availableCardsCount
                )
            }
            mergeSyncedCards(syncedCards)
            print("✅ Watch received \(syncedCards.count) cards")
        } catch {
            print("⚠️ Failed to decode watch cards payload: \(error.localizedDescription)")
        }
    }
}

// MARK: - Watch Card Display Model

struct WatchCardDisplay: Codable, Identifiable {
    let id: String
    let cardName: String
    let barcodeType: String
    let payload: String
    let locationName: String?
    let availableCardsCount: Int
    
    init(cardId: String, cardName: String, barcodeType: String, payload: String, locationName: String?, availableCardsCount: Int) {
        self.id = cardId
        self.cardName = cardName
        self.barcodeType = barcodeType
        self.payload = payload
        self.locationName = locationName
        self.availableCardsCount = availableCardsCount
    }
}

private struct WatchSyncSnapshotDTO: Codable {
    let cards: [WatchSyncCardDTO]
    let syncedAt: TimeInterval
}

private struct WatchSyncCardDTO: Codable {
    let id: String
    let cardName: String
    let barcodeType: String
    let payload: String
    let locationName: String?
    let availableCardsCount: Int
}

