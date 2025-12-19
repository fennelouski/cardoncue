import Foundation
import SwiftData
import CoreLocation

@Model
final class SavedLocation {
    var id: UUID = UUID()
    var name: String = ""              // Normalized name for matching
    var displayName: String = ""       // Original name for display
    var address: String?          // Full formatted address
    var latitude: Double?
    var longitude: Double?
    var lastUsedDate: Date = Date()        // For sorting by recency
    var usageCount: Int = 1           // How many cards use this

    // Business metadata
    var phoneNumber: String?      // Business phone number
    var website: String?          // Business website URL
    var hours: String?            // Operating hours (JSON string)
    var email: String?            // Business email
    var socialMedia: String?      // Social media handles (JSON string)
    var notes: String?            // Additional notes

    // Icon/Logo data
    var iconType: String?         // CardIconType raw value (sfSymbol, image, emoji, etc.)
    var iconValue: String?        // Icon data (symbol name, emoji, or image file path)
    var iconColorHex: String?     // Icon color (for SF Symbols)
    var iconBackgroundColorHex: String? // Background color (for SF Symbols)

    init(
        id: UUID = UUID(),
        name: String,
        displayName: String,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        lastUsedDate: Date = Date(),
        usageCount: Int = 1,
        phoneNumber: String? = nil,
        website: String? = nil,
        hours: String? = nil,
        email: String? = nil,
        socialMedia: String? = nil,
        notes: String? = nil,
        iconType: String? = nil,
        iconValue: String? = nil,
        iconColorHex: String? = nil,
        iconBackgroundColorHex: String? = nil
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.lastUsedDate = lastUsedDate
        self.usageCount = usageCount
        self.phoneNumber = phoneNumber
        self.website = website
        self.hours = hours
        self.email = email
        self.socialMedia = socialMedia
        self.notes = notes
        self.iconType = iconType
        self.iconValue = iconValue
        self.iconColorHex = iconColorHex
        self.iconBackgroundColorHex = iconBackgroundColorHex
    }

    // Computed property for easy coordinate access
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // Calculate distance from a given coordinate
    func distance(from location: CLLocationCoordinate2D?) -> Double? {
        guard let location = location,
              let coordinate = self.coordinate else { return nil }

        let from = CLLocation(latitude: location.latitude, longitude: location.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return from.distance(from: to)
    }

    // Convert stored icon data to CardIcon
    var cardIcon: CardIcon? {
        get {
            guard let typeString = iconType,
                  let type = CardIconType(rawValue: typeString),
                  let value = iconValue else { return nil }

            return CardIcon(
                type: type,
                value: value,
                colorHex: iconColorHex,
                backgroundColorHex: iconBackgroundColorHex
            )
        }
        set {
            if let newValue = newValue {
                iconType = newValue.type.rawValue
                iconValue = newValue.value
                iconColorHex = newValue.colorHex
                iconBackgroundColorHex = newValue.backgroundColorHex
            } else {
                iconType = nil
                iconValue = nil
                iconColorHex = nil
                iconBackgroundColorHex = nil
            }
        }
    }
}
