import Foundation

struct CardLocation: Identifiable, Codable, Hashable {
    let id: String
    let cardId: String
    let userId: String
    var locationName: String
    var address: String?
    var city: String?
    var state: String?
    var country: String?
    var postalCode: String?
    var latitude: Double?
    var longitude: Double?
    var notes: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case cardId = "card_id"
        case userId = "user_id"
        case locationName = "location_name"
        case address
        case city
        case state
        case country
        case postalCode = "postal_code"
        case latitude
        case longitude
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CardLocationRequest: Codable {
    let userId: String
    let locationName: String
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let postalCode: String?
    let latitude: Double?
    let longitude: Double?
    let notes: String?
}
