import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var shared: AppDelegate?

    // Navigation state for deep linking
    var pendingCardId: String?
    var pendingAction: NotificationAction = .none

    enum NotificationAction {
        case none
        case openCard(String)
        case selectCard
        case startLiveActivity(String, String, Int)  // cardId, locationName, count
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AppDelegate.shared = self

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Called when notification is received while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        return [.banner, .sound, .badge]
    }

    // Called when user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo

        print("📱 Notification tapped with userInfo: \(userInfo)")

        // Parse notification action
        if let action = userInfo["action"] as? String {
            switch action {
            case "openCard":
                if let cardId = userInfo["cardId"] as? String {
                    print("📱 Opening card: \(cardId)")
                    await MainActor.run {
                        pendingAction = .openCard(cardId)
                        pendingCardId = cardId

                        // Post notification to trigger UI update
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenCardFromNotification"),
                            object: nil,
                            userInfo: ["cardId": cardId]
                        )
                    }
                }

            case "selectCard":
                print("📱 Opening card selector")
                await MainActor.run {
                    pendingAction = .selectCard

                    // Post notification to trigger card selector
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowCardSelectorFromNotification"),
                        object: nil,
                        userInfo: userInfo
                    )
                }

            case "startLiveActivity":
                if let cardId = userInfo["cardId"] as? String,
                   let locationName = userInfo["locationName"] as? String,
                   let availableCardsCount = userInfo["availableCardsCount"] as? Int {
                    print("📱 Starting Live Activity for: \(cardId) at \(locationName)")
                    await MainActor.run {
                        pendingAction = .startLiveActivity(cardId, locationName, availableCardsCount)

                        // Post notification for the main app to handle
                        NotificationCenter.default.post(
                            name: NSNotification.Name("StartLiveActivityFromGeofence"),
                            object: nil,
                            userInfo: [
                                "cardId": cardId,
                                "locationName": locationName,
                                "availableCardsCount": availableCardsCount
                            ]
                        )
                    }
                }

            default:
                print("⚠️ Unknown notification action: \(action)")
            }
        } else if let cardId = userInfo["cardId"] as? String {
            // Legacy fallback - just cardId without action
            print("📱 Opening card (legacy): \(cardId)")
            await MainActor.run {
                pendingAction = .openCard(cardId)
                pendingCardId = cardId

                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenCardFromNotification"),
                    object: nil,
                    userInfo: ["cardId": cardId]
                )
            }
        }
    }

    func clearPendingAction() {
        pendingAction = .none
        pendingCardId = nil
    }
}
