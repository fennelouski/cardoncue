import Foundation
import UserNotifications
#if os(watchOS)
import WatchKit
#endif

/// Manages notifications and card display on watchOS
@MainActor
class WatchNotificationManager: NSObject, ObservableObject {
    static let shared = WatchNotificationManager()
    
    @Published var currentCard: WatchCardDisplay?
    
    private let persistenceKey = "watchLastDisplayedCard"
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
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
    
    /// Clear persisted card
    func clearPersistedCard() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
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

