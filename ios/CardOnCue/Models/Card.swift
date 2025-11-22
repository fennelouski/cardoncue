import Foundation

/// Represents a membership/loyalty card
struct Card: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    var name: String
    var barcodeType: BarcodeType
    var payload: String // Decrypted barcode payload (actual number/text)
    var tags: [String]
    var networkIds: [String]
    var validFrom: Date?
    var validTo: Date?
    var oneTime: Bool
    var usedAt: Date?
    var metadata: [String: String]
    let createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

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
    mutating func markAsUsed() {
        guard oneTime else { return }
        usedAt = Date()
        updatedAt = Date()
    }

    /// Helper to get metadata value
    func metadata(for key: String) -> String? {
        return metadata[key]
    }

    /// Helper to set metadata value
    mutating func setMetadata(_ value: String?, for key: String) {
        if let value = value {
            metadata[key] = value
        } else {
            metadata.removeValue(forKey: key)
        }
        updatedAt = Date()
    }
}

// MARK: - Encrypted Card (for storage/transmission)

/// Encrypted representation of card payload
struct EncryptedCard: Codable {
    let id: String
    let userId: String
    var name: String
    var barcodeType: BarcodeType
    var ciphertext: Data
    var nonce: Data
    var tag: Data
    var tags: [String]
    var networkIds: [String]
    var validFrom: Date?
    var validTo: Date?
    var oneTime: Bool
    var usedAt: Date?
    var metadata: [String: String]
    let createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    /// Convert to API format (Base64-encoded)
    var payloadEncrypted: String {
        // Format: "nonce:ciphertext:tag" (all Base64)
        let nonceB64 = nonce.base64EncodedString()
        let ciphertextB64 = ciphertext.base64EncodedString()
        let tagB64 = tag.base64EncodedString()
        return "\(nonceB64):\(ciphertextB64):\(tagB64)"
    }

    /// Parse from API format
    static func parsePayloadEncrypted(_ payloadEncrypted: String) -> (nonce: Data, ciphertext: Data, tag: Data)? {
        let parts = payloadEncrypted.split(separator: ":")
        guard parts.count == 3 else { return nil }

        guard let nonce = Data(base64Encoded: String(parts[0])),
              let ciphertext = Data(base64Encoded: String(parts[1])),
              let tag = Data(base64Encoded: String(parts[2])) else {
            return nil
        }

        return (nonce, ciphertext, tag)
    }
}
