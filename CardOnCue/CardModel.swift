import Foundation
import SwiftData

/// SwiftData model for membership/loyalty cards with iCloud sync support
@Model
final class CardModel {
    // CloudKit requires all properties to be optional or have defaults
    // Unique constraint not supported with CloudKit
    var id: String = UUID().uuidString
    var userId: String = ""
    var name: String = ""
    var barcodeTypeRaw: String = "qr"
    var payloadEncrypted: Data = Data() // Encrypted barcode payload
    var tags: [String] = []
    var networkIds: [String] = []
    var validFrom: Date? = nil
    var validTo: Date? = nil
    var oneTime: Bool = false
    var usedAt: Date? = nil
    var metadata: [String: String] = [:]
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var archivedAt: Date? = nil

    // Location data for geofencing
    var locationLatitude: Double? = nil
    var locationLongitude: Double? = nil
    var locationRadius: Double = 100.0 // Default 100m radius
    var locationName: String? = nil // e.g., "LA Fitness - Main St"
    var isGeofenceActive: Bool = false // Is this currently one of the 20 monitored?
    
    // Image data for card photos
    var originalImageURL: String? = nil // File path to original image
    var processedImageURL: String? = nil // File path to processed (cropped/straightened) image
    var processingConfidence: Double? = nil // Confidence score from 0.0 to 1.0
    var useProcessedImage: Bool = true // Whether to use processed image by default
    var processingMetadataJSON: String? = nil // JSON-encoded ProcessingMetadata

    // Barcode cropping support
    var barcodeBoundingBox: CGRect? = nil // Normalized (0-1) coords from Vision
    var croppedBarcodeImageURL: String? = nil // Cached cropped barcode image
    var prefersCroppedBarcode: Bool = false // User's toggle preference
    
    // Icon for card display
    var iconName: String? = nil // Legacy: SF Symbol name (for backward compatibility)
    var iconDataJSON: String? = nil // JSON-encoded CardIcon data
    var drawingDataURL: String? = nil // File path to PKDrawing data for editing

    // OCR extracted text data
    var ocrDataJSON: String? = nil // JSON-encoded OCRData

    // Computed property for barcode type
    var barcodeType: BarcodeType {
        get { BarcodeType(rawValue: barcodeTypeRaw) ?? .qr }
        set { barcodeTypeRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        barcodeType: BarcodeType,
        payloadEncrypted: Data,
        tags: [String] = [],
        networkIds: [String] = [],
        validFrom: Date? = nil,
        validTo: Date? = nil,
        oneTime: Bool = false,
        usedAt: Date? = nil,
        metadata: [String: String] = [:],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        archivedAt: Date? = nil,
        iconName: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.barcodeTypeRaw = barcodeType.rawValue
        self.payloadEncrypted = payloadEncrypted
        self.tags = tags
        self.networkIds = networkIds
        self.validFrom = validFrom
        self.validTo = validTo
        self.oneTime = oneTime
        self.usedAt = usedAt
        self.metadata = metadata
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
        self.iconName = iconName
    }

    /// Is this card currently valid?
    var isValid: Bool {
        let now = Date()
        if let from = validFrom, from > now {
            return false // Not yet valid
        }
        if let to = validTo, to < now {
            return false // Expired
        }
        if oneTime && usedAt != nil {
            return false // Already used
        }
        return true
    }

    /// Is this card expired?
    var isExpired: Bool {
        if let to = validTo, to < Date() {
            return true
        }
        if oneTime && usedAt != nil {
            return true
        }
        return false
    }

    /// Days until expiration (if applicable)
    var daysUntilExpiration: Int? {
        guard let validTo = validTo else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: validTo).day
        return days
    }

    /// Mark card as used (for one-time cards)
    func markAsUsed() {
        guard oneTime else { return }
        usedAt = Date()
        updatedAt = Date()
    }

    /// Helper to get metadata value
    func getMetadata(for key: String) -> String? {
        return metadata[key]
    }

    /// Helper to set metadata value
    func setMetadata(_ value: String?, for key: String) {
        if let value = value {
            metadata[key] = value
        } else {
            metadata.removeValue(forKey: key)
        }
        updatedAt = Date()
    }
    
    // MARK: - Image Helpers
    
    /// Get the display image URL (processed if available and preferred, otherwise original)
    var displayImageURL: String? {
        if useProcessedImage, let processed = processedImageURL {
            return processed
        }
        return originalImageURL
    }
    
    /// Set processing metadata
    func setProcessingMetadata(_ metadata: ProcessingMetadata?) {
        // Encode in nonisolated context since ProcessingMetadata is Sendable
        let jsonString = Self.encodeProcessingMetadata(metadata)
        processingMetadataJSON = jsonString
        updatedAt = Date()
    }
    
    /// Get processing metadata
    func getProcessingMetadata() -> ProcessingMetadata? {
        guard let jsonString = processingMetadataJSON else {
            return nil
        }
        // Decode in nonisolated context since ProcessingMetadata is Sendable
        return Self.decodeProcessingMetadata(jsonString)
    }
    
    /// Nonisolated helper to encode ProcessingMetadata
    nonisolated private static func encodeProcessingMetadata(_ metadata: ProcessingMetadata?) -> String? {
        guard let metadata = metadata else { return nil }
        // Manually serialize to avoid Codable main actor isolation
        let dict: [String: Any] = [
            "algorithmVersion": metadata.algorithmVersion,
            "detectionConfidence": metadata.detectionConfidence,
            "cornersDetected": metadata.cornersDetected,
            "processingTimeMs": metadata.processingTimeMs,
            "enhancementsApplied": metadata.enhancementsApplied,
            "originalDimensions": ["width": metadata.originalDimensions.width, "height": metadata.originalDimensions.height],
            "processedDimensions": metadata.processedDimensions.map { ["width": $0.width, "height": $0.height] } as Any
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return data.base64EncodedString()
    }

    /// Nonisolated helper to decode ProcessingMetadata
    nonisolated private static func decodeProcessingMetadata(_ jsonString: String) -> ProcessingMetadata? {
        guard let data = Data(base64Encoded: jsonString),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let algorithmVersion = dict["algorithmVersion"] as? String,
              let detectionConfidence = dict["detectionConfidence"] as? Float,
              let cornersDetected = dict["cornersDetected"] as? [[Double]],
              let processingTimeMs = dict["processingTimeMs"] as? Int,
              let enhancementsApplied = dict["enhancementsApplied"] as? [String],
              let originalDimDict = dict["originalDimensions"] as? [String: Int],
              let origWidth = originalDimDict["width"],
              let origHeight = originalDimDict["height"] else {
            return nil
        }

        let processedDimensions: ImageDimensions?
        if let procDimDict = dict["processedDimensions"] as? [String: Int],
           let procWidth = procDimDict["width"],
           let procHeight = procDimDict["height"] {
            processedDimensions = ImageDimensions(width: procWidth, height: procHeight)
        } else {
            processedDimensions = nil
        }

        return ProcessingMetadata(
            algorithmVersion: algorithmVersion,
            detectionConfidence: detectionConfidence,
            cornersDetected: cornersDetected,
            processingTimeMs: processingTimeMs,
            enhancementsApplied: enhancementsApplied,
            originalDimensions: ImageDimensions(width: origWidth, height: origHeight),
            processedDimensions: processedDimensions
        )
    }
    
    // MARK: - Icon Helpers
    
    /// Get the card icon
    func getIcon() -> CardIcon? {
        // Try new icon format first
        if let jsonString = iconDataJSON {
            if let icon = Self.decodeCardIcon(jsonString) {
                return icon
            }
        }
        
        // Fall back to legacy iconName
        if let iconName = iconName, !iconName.isEmpty {
            return CardIcon.sfSymbol(iconName)
        }
        
        return nil
    }
    
    /// Set the card icon
    func setIcon(_ icon: CardIcon?) {
        if let icon = icon {
            let jsonString = Self.encodeCardIcon(icon)
            iconDataJSON = jsonString
            // Also update legacy iconName for backward compatibility
            if icon.type == .sfSymbol {
                iconName = icon.value
            } else {
                iconName = nil
            }
        } else {
            iconDataJSON = nil
            iconName = nil
        }
        updatedAt = Date()
    }
    
    /// Nonisolated helper to encode CardIcon
    nonisolated private static func encodeCardIcon(_ icon: CardIcon) -> String? {
        // Manually serialize to avoid Codable main actor isolation
        var dict: [String: Any] = [
            "type": icon.type.rawValue,
            "value": icon.value
        ]
        if let colorHex = icon.colorHex {
            dict["colorHex"] = colorHex
        }
        if let backgroundColorHex = icon.backgroundColorHex {
            dict["backgroundColorHex"] = backgroundColorHex
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return data.base64EncodedString()
    }

    /// Nonisolated helper to decode CardIcon
    nonisolated private static func decodeCardIcon(_ jsonString: String) -> CardIcon? {
        guard let data = Data(base64Encoded: jsonString),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let typeString = dict["type"] as? String,
              let type = CardIconType(rawValue: typeString),
              let value = dict["value"] as? String else {
            return nil
        }

        let colorHex = dict["colorHex"] as? String
        let backgroundColorHex = dict["backgroundColorHex"] as? String

        return CardIcon(
            type: type,
            value: value,
            colorHex: colorHex,
            backgroundColorHex: backgroundColorHex
        )
    }
}

// MARK: - Extensions for computed properties
extension CardModel {
    var expiryInfo: String? {
        if let daysUntilExpiration = daysUntilExpiration {
            if daysUntilExpiration <= 0 {
                return "Expired"
            } else if daysUntilExpiration <= 7 {
                return "Expires in \(daysUntilExpiration) days"
            } else if daysUntilExpiration <= 30 {
                return "Expires in \(daysUntilExpiration) days"
            }
        }
        return nil
    }
}

// MARK: - Brand Name Extraction
extension CardModel {
    /// Extract brand name from card name for grouping
    var brandName: String {
        // Check metadata for explicit override
        if let explicitBrand = metadata["brandName"], !explicitBrand.isEmpty {
            return explicitBrand
        }

        // Auto-extract from name
        return Self.extractBrandName(from: name, locationName: locationName)
    }

    /// Static helper for brand extraction
    static func extractBrandName(from cardName: String, locationName: String?) -> String {
        // Priority 1: Use locationName if it looks like a business
        if let location = locationName, !location.isEmpty {
            let locationLower = location.lowercased()
            // Exclude generic location terms
            let genericTerms = ["card", "membership", "library", "gym", "fitness", "store"]
            let hasGenericTerm = genericTerms.contains { locationLower.contains($0) }

            if !hasGenericTerm {
                // Clean up location name (e.g., "LA Fitness - Main St" → "LA Fitness")
                let cleaned = cleanBrandName(location)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        }

        // Priority 2: Extract from card name
        var cleaned = cardName

        // Remove possessive forms: "Luke's Louisville Library Card" → "Louisville Library Card"
        cleaned = cleaned.replacingOccurrences(
            of: #"^[A-Za-z]+'s\s+"#,
            with: "",
            options: .regularExpression
        )

        // Remove common suffixes
        let suffixes = [
            " Card", " Membership", " Member", " Loyalty",
            " Rewards", " Account", " Pass", " Program"
        ]
        for suffix in suffixes {
            cleaned = cleaned.replacingOccurrences(of: suffix, with: "", options: .caseInsensitive)
        }

        // Remove common prefixes
        let prefixes = ["My ", "The ", "A "]
        for prefix in prefixes {
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }

        // Split by separators and take first part
        let separators = [" - ", " – ", " — ", " | ", " / ", " at "]
        for separator in separators {
            if let firstPart = cleaned.components(separatedBy: separator).first,
               !firstPart.isEmpty {
                cleaned = firstPart.trimmingCharacters(in: .whitespaces)
                break
            }
        }

        let result = cleaned.trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? "Other" : result
    }

    private static func cleanBrandName(_ name: String) -> String {
        // Remove location-specific suffixes like " - Main St", " Downtown"
        var cleaned = name
        let locationSuffixes = [
            #"\s+-\s+[A-Za-z0-9\s]+"#,  // " - Main St"
            #"\s+Downtown$"#,
            #"\s+\([^)]+\)$"#  // " (Location)"
        ]

        for pattern in locationSuffixes {
            cleaned = cleaned.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Encryption Helper
extension CardModel {
    /// Encrypt a payload and create a CardModel
    static func createWithEncryptedPayload(
        userId: String,
        name: String,
        barcodeType: BarcodeType,
        payload: String,
        masterKey: SymmetricKey,
        tags: [String] = [],
        networkIds: [String] = [],
        validFrom: Date? = nil,
        validTo: Date? = nil,
        oneTime: Bool = false,
        metadata: [String: String] = [:],
        iconName: String? = nil
    ) throws -> CardModel {
        // Encrypt the payload
        guard let data = payload.data(using: .utf8) else {
            throw CardEncryptionError.invalidPayload
        }

        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: masterKey, nonce: nonce)

        // Combine nonce, ciphertext, and tag into single Data blob
        var encryptedData = Data()
        encryptedData.append(nonce.withUnsafeBytes { Data($0) })
        encryptedData.append(sealedBox.ciphertext)
        encryptedData.append(sealedBox.tag)

        return CardModel(
            userId: userId,
            name: name,
            barcodeType: barcodeType,
            payloadEncrypted: encryptedData,
            tags: tags,
            networkIds: networkIds,
            validFrom: validFrom,
            validTo: validTo,
            oneTime: oneTime,
            metadata: metadata,
            iconName: iconName
        )
    }

    /// Decrypt the payload
    func decryptPayload(masterKey: SymmetricKey) throws -> String {
        // Extract nonce (12 bytes), ciphertext, and tag (16 bytes)
        guard payloadEncrypted.count >= 28 else { // 12 + 16 = 28 minimum
            throw CardEncryptionError.invalidEncryptedData
        }

        let nonceData = payloadEncrypted.prefix(12)
        let tagData = payloadEncrypted.suffix(16)
        let ciphertext = payloadEncrypted.dropFirst(12).dropLast(16)

        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: ciphertext,
            tag: tagData
        )

        let decrypted = try AES.GCM.open(sealedBox, using: masterKey)

        guard let payload = String(data: decrypted, encoding: .utf8) else {
            throw CardEncryptionError.decryptionFailed
        }

        return payload
    }
}

enum CardEncryptionError: LocalizedError {
    case invalidPayload
    case invalidEncryptedData
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Invalid payload data"
        case .invalidEncryptedData:
            return "Invalid encrypted data format"
        case .decryptionFailed:
            return "Failed to decrypt card payload"
        }
    }
}

// MARK: - OCR Data Helpers
extension CardModel {
    /// Get OCR data
    func getOCRData() -> OCRData? {
        guard let jsonString = ocrDataJSON else { return nil }
        return Self.decodeOCRData(jsonString)
    }

    /// Set OCR data
    func setOCRData(_ data: OCRData?) {
        ocrDataJSON = Self.encodeOCRData(data)
        updatedAt = Date()
    }

    /// Nonisolated helper to encode OCRData
    nonisolated private static func encodeOCRData(_ data: OCRData?) -> String? {
        guard let data = data else { return nil }

        let dict: [String: Any] = [
            "fullText": data.fullText,
            "segments": data.segments.map { segment in
                var segmentDict: [String: Any] = [
                    "id": segment.id,
                    "type": segment.type.rawValue,
                    "value": segment.value
                ]
                if let confidence = segment.confidence {
                    segmentDict["confidence"] = confidence
                }
                if let sourceLineIndex = segment.sourceLineIndex {
                    segmentDict["sourceLineIndex"] = sourceLineIndex
                }
                return segmentDict
            },
            "extractedAt": data.extractedAt.timeIntervalSince1970,
            "confidence": data.confidence,
            "algorithmVersion": data.algorithmVersion
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return jsonData.base64EncodedString()
    }

    /// Helper to decode OCRData
    private static func decodeOCRData(_ jsonString: String) -> OCRData? {
        guard let data = Data(base64Encoded: jsonString),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fullText = dict["fullText"] as? String,
              let segmentsArray = dict["segments"] as? [[String: Any]],
              let extractedAtTimestamp = dict["extractedAt"] as? TimeInterval,
              let confidence = dict["confidence"] as? Float,
              let algorithmVersion = dict["algorithmVersion"] as? String else {
            return nil
        }

        let segments = segmentsArray.compactMap { segmentDict -> OCRField? in
            guard let id = segmentDict["id"] as? String,
                  let typeRaw = segmentDict["type"] as? String,
                  let type = OCRFieldType(rawValue: typeRaw),
                  let value = segmentDict["value"] as? String else {
                return nil
            }

            let confidence = segmentDict["confidence"] as? Float
            let sourceLineIndex = segmentDict["sourceLineIndex"] as? Int

            return OCRField(id: id, type: type, value: value, confidence: confidence, sourceLineIndex: sourceLineIndex)
        }

        let extractedAt = Date(timeIntervalSince1970: extractedAtTimestamp)

        return OCRData(fullText: fullText, segments: segments, extractedAt: extractedAt, confidence: confidence, algorithmVersion: algorithmVersion)
    }
}

import CryptoKit
