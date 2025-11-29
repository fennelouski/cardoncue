import Foundation
import ActivityKit

struct CardLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var brightness: Double
        var lastUpdate: Date
        var locationName: String?  // e.g., "Costco - Main St"
        var availableCardsCount: Int  // Number of cards available at this location
    }

    let cardId: String
    let cardName: String
    let barcodeType: String
    let payload: String
    let triggeredByLocation: Bool  // Was this activity started by geofence?
}
