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
        archivedAt: Date? = nil
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
        metadata: [String: String] = [:]
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
            metadata: metadata
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

import CryptoKit
