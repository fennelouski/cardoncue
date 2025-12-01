import Foundation

struct Card: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    var name: String
    var barcodeType: BarcodeType
    var payload: String
    var tags: [String]
    var networkIds: [String]
    var validFrom: Date?
    var validTo: Date?
    var oneTime: Bool
    var usedAt: Date?
    var metadata: [String: String]
    let createdAt: Date
    var updatedAt: Date
    var defaultIconUrl: String?
    var customIconUrl: String?
    var cardType: CardType
    var giftCardBrandId: String?
    var currentBalance: Decimal?
    var balanceCurrency: String?
    var balanceLastUpdated: Date?
    var barcodeImageData: BarcodeImageData?
    var frontCardImage: CardFrontImage?
    var barcodeRepresentationPreference: BarcodeRepresentation
    var barcodeQualityMetrics: BarcodeQualityMetrics?

    var isExpired: Bool {
        guard let validTo = validTo else { return false }
        return validTo < Date()
    }

    var daysUntilExpiration: Int? {
        guard let validTo = validTo else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: validTo).day
        return days
    }

    var iconUrl: String? {
        return customIconUrl ?? defaultIconUrl
    }

    var isGiftCard: Bool {
        return cardType == .giftCard
    }

    var effectiveBarcodeRepresentation: BarcodeRepresentation {
        if barcodeRepresentationPreference == .automatic {
            guard let imageData = barcodeImageData,
                  let metrics = barcodeQualityMetrics else {
                return .digital
            }

            // Generated barcodes are almost always better than scanned ones.
            // Only use scanned if it's exceptionally high quality (90%+) AND
            // has very high readability (95%+). This ensures lock screen scanning works reliably.
            let isExceptionalQuality = metrics.overallScore >= 0.90 && metrics.readabilityScore >= 0.95
            return isExceptionalQuality ? .scannedImage : .digital
        }
        return barcodeRepresentationPreference
    }

    var shouldUseScannedBarcode: Bool {
        effectiveBarcodeRepresentation == .scannedImage && barcodeImageData != nil
    }

    var displayIconUrl: String? {
        if let frontImage = frontCardImage {
            return frontImage.localFilePath
        }
        return iconUrl
    }

    enum CodingKeys: String, CodingKey {
        case id, userId, name, barcodeType, payload, tags, networkIds
        case validFrom, validTo, oneTime, usedAt, metadata, createdAt, updatedAt
        case defaultIconUrl = "default_icon_url"
        case customIconUrl = "custom_icon_url"
        case cardType = "card_type"
        case giftCardBrandId = "gift_card_brand_id"
        case currentBalance = "current_balance"
        case balanceCurrency = "balance_currency"
        case balanceLastUpdated = "balance_last_updated"
        case barcodeImageData = "barcode_image_data"
        case frontCardImage = "front_card_image"
        case barcodeRepresentationPreference = "barcode_representation_preference"
        case barcodeQualityMetrics = "barcode_quality_metrics"
    }
}

extension Card {
    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        barcodeType: BarcodeType,
        payload: String,
        tags: [String] = [],
        networkIds: [String] = [],
        validFrom: Date? = nil,
        validTo: Date? = nil,
        oneTime: Bool = false,
        usedAt: Date? = nil,
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        defaultIconUrl: String? = nil,
        customIconUrl: String? = nil,
        cardType: CardType,
        giftCardBrandId: String? = nil,
        currentBalance: Decimal? = nil,
        balanceCurrency: String? = nil,
        balanceLastUpdated: Date? = nil,
        barcodeImageData: BarcodeImageData? = nil,
        frontCardImage: CardFrontImage? = nil,
        barcodeRepresentationPreference: BarcodeRepresentation = .automatic,
        barcodeQualityMetrics: BarcodeQualityMetrics? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.barcodeType = barcodeType
        self.payload = payload
        self.tags = tags
        self.networkIds = networkIds
        self.validFrom = validFrom
        self.validTo = validTo
        self.oneTime = oneTime
        self.usedAt = usedAt
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.defaultIconUrl = defaultIconUrl
        self.customIconUrl = customIconUrl
        self.cardType = cardType
        self.giftCardBrandId = giftCardBrandId
        self.currentBalance = currentBalance
        self.balanceCurrency = balanceCurrency
        self.balanceLastUpdated = balanceLastUpdated
        self.barcodeImageData = barcodeImageData
        self.frontCardImage = frontCardImage
        self.barcodeRepresentationPreference = barcodeRepresentationPreference
        self.barcodeQualityMetrics = barcodeQualityMetrics
    }
}

enum BarcodeType: String, Codable {
    case qr
    case code128
    case pdf417
    case aztec
    case ean13
    case upcA = "upc_a"
    case code39
    case itf
}
