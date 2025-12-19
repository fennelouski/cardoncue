import Foundation

/// Complete OCR extraction data for a card
struct OCRData: Sendable, Codable {
    let fullText: String
    let segments: [OCRField]
    let extractedAt: Date
    let confidence: Float
    let algorithmVersion: String

    init(fullText: String, segments: [OCRField], extractedAt: Date = Date(), confidence: Float, algorithmVersion: String = "1.0") {
        self.fullText = fullText
        self.segments = segments
        self.extractedAt = extractedAt
        self.confidence = confidence
        self.algorithmVersion = algorithmVersion
    }
}

/// Individual OCR field segment
struct OCRField: Sendable, Codable, Identifiable {
    let id: String
    let type: OCRFieldType
    var value: String
    let confidence: Float?
    let sourceLineIndex: Int? // Which line(s) from original OCR

    init(id: String = UUID().uuidString, type: OCRFieldType, value: String, confidence: Float? = nil, sourceLineIndex: Int? = nil) {
        self.id = id
        self.type = type
        self.value = value
        self.confidence = confidence
        self.sourceLineIndex = sourceLineIndex
    }
}

/// Types of fields that can be auto-detected
enum OCRFieldType: String, Sendable, Codable, CaseIterable {
    case personName = "person_name"
    case address = "address"
    case memberId = "member_id"
    case membershipLevel = "membership_level"
    case season = "season"
    case expirationDate = "expiration_date"
    case phoneNumber = "phone_number"
    case email = "email"
    case website = "website"
    case pin = "pin"
    case cardType = "card_type"
    case other = "other"

    var displayName: String {
        switch self {
        case .personName: return "Name"
        case .address: return "Address"
        case .memberId: return "ID/Member Number"
        case .membershipLevel: return "Membership Level"
        case .season: return "Season/Year"
        case .expirationDate: return "Expiration Date"
        case .phoneNumber: return "Phone"
        case .email: return "Email"
        case .website: return "Website"
        case .pin: return "PIN"
        case .cardType: return "Card Type"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .personName: return "person.fill"
        case .address: return "mappin.and.ellipse"
        case .memberId: return "number"
        case .membershipLevel: return "star.fill"
        case .season: return "calendar.badge.clock"
        case .expirationDate: return "calendar"
        case .phoneNumber: return "phone.fill"
        case .email: return "envelope.fill"
        case .website: return "link"
        case .pin: return "lock.fill"
        case .cardType: return "creditcard.fill"
        case .other: return "text.alignleft"
        }
    }
}
