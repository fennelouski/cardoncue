import Foundation
import ActivityKit
import Combine

/// Coordinates automatic Live Activity startup when geofences are entered
/// Listens to notifications from GeofenceManager and starts Live Activities
@MainActor
class GeofenceActivityCoordinator: ObservableObject {
    private let storageService: StorageService
    private var cancellables = Set<AnyCancellable>()

    init(storageService: StorageService) {
        self.storageService = storageService
        setupListeners()
        print("✅ GeofenceActivityCoordinator initialized and listening")
    }

    private func setupListeners() {
        // Listen for geofence entry notifications from GeofenceManager
        NotificationCenter.default.publisher(for: NSNotification.Name("StartLiveActivityFromGeofence"))
            .sink { [weak self] notification in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handleGeofenceEntry(notification)
                }
            }
            .store(in: &cancellables)
    }

    private func handleGeofenceEntry(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let cardId = userInfo["cardId"] as? String,
              let locationName = userInfo["locationName"] as? String,
              let count = userInfo["availableCardsCount"] as? Int else {
            print("⚠️ Invalid geofence notification data")
            return
        }

        print("📍 Geofence entered for card: \(cardId) at \(locationName)")

        // Get the card from StorageService
        guard let card = storageService.getCard(by: cardId) else {
            print("❌ Card not found: \(cardId)")
            return
        }

        // Start Live Activity automatically
        if #available(iOS 16.1, *) {
            do {
                try LiveActivityService.shared.startActivity(
                    for: card,
                    locationName: locationName,
                    availableCardsCount: count
                )
                print("✅ Auto-started Live Activity: \(card.name) at \(locationName)")
            } catch {
                print("❌ Failed to start Live Activity: \(error)")
            }
        }
    }
}
