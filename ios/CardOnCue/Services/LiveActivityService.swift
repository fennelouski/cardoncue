import Foundation
import ActivityKit

@available(iOS 16.1, *)
class LiveActivityService {
    static let shared = LiveActivityService()

    private var currentActivity: Activity<CardLiveActivityAttributes>?

    private init() {}

    enum LiveActivityError: Error {
        case activitiesNotSupported
        case activityStartFailed
        case activityUpdateFailed
        case noActiveActivity
    }

    func startActivity(for card: Card, locationName: String? = nil, availableCardsCount: Int = 1) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.activitiesNotSupported
        }

        endCurrentActivity()

        let attributes = CardLiveActivityAttributes(
            cardId: card.id,
            cardName: card.name,
            barcodeType: card.barcodeType.rawValue,
            payload: card.payload,
            triggeredByLocation: locationName != nil
        )

        let initialState = CardLiveActivityAttributes.ContentState(
            brightness: 1.0,
            lastUpdate: Date(),
            locationName: locationName,
            availableCardsCount: availableCardsCount
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
        } catch {
            throw LiveActivityError.activityStartFailed
        }
    }

    func updateBrightness(_ brightness: Double) async throws {
        guard let activity = currentActivity else {
            throw LiveActivityError.noActiveActivity
        }

        let currentState = activity.content.state
        let updatedState = CardLiveActivityAttributes.ContentState(
            brightness: brightness,
            lastUpdate: Date(),
            locationName: currentState.locationName,
            availableCardsCount: currentState.availableCardsCount
        )

        await activity.update(using: updatedState)
    }

    func updateLocationInfo(locationName: String?, availableCardsCount: Int) async throws {
        guard let activity = currentActivity else {
            throw LiveActivityError.noActiveActivity
        }

        let currentState = activity.content.state
        let updatedState = CardLiveActivityAttributes.ContentState(
            brightness: currentState.brightness,
            lastUpdate: Date(),
            locationName: locationName,
            availableCardsCount: availableCardsCount
        )

        await activity.update(using: updatedState)
    }

    func endCurrentActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        currentActivity = nil
    }

    func endAllActivities() {
        Task {
            for activity in Activity<CardLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }

    var isActivityActive: Bool {
        currentActivity != nil && currentActivity?.activityState == .active
    }

    var currentBrightness: Double {
        currentActivity?.content.state.brightness ?? 1.0
    }
}
