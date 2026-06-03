import Foundation
import CryptoKit

/// Ensures a CardModel has a corresponding Postgres row for crowdsourced location reporting.
enum CardServerSync {
    private static let serverCardIdKey = "serverCardId"

    static func serverCardId(for card: CardModel) -> String? {
        card.metadata[serverCardIdKey]
    }

    static func setServerCardId(_ id: String, on card: CardModel) {
        card.setMetadata(id, for: serverCardIdKey)
    }

    /// Returns the server card id used for location submission APIs.
    static func ensureServerCardId(
        card: CardModel,
        apiClient: APIClient,
        keychainService: KeychainService
    ) async throws -> String {
        if let existing = serverCardId(for: card), !existing.isEmpty {
            return existing
        }

        guard let masterKey = try keychainService.getMasterKey() else {
            throw APIClient.APIError.unauthorized
        }

        let encrypted = try card.makeEncryptedCard(masterKey: masterKey)
        let syncedId = try await apiClient.syncCard(encrypted)
        setServerCardId(syncedId, on: card)
        return syncedId
    }
}

extension CardModel {
    func makeEncryptedCard(masterKey: SymmetricKey) throws -> EncryptedCard {
        guard payloadEncrypted.count >= 28 else {
            throw CardEncryptionError.invalidEncryptedData
        }

        let nonceData = payloadEncrypted.prefix(12)
        let tagData = payloadEncrypted.suffix(16)
        let ciphertext = payloadEncrypted.dropFirst(12).dropLast(16)

        return EncryptedCard(
            id: id,
            userId: userId,
            name: name,
            barcodeType: barcodeType,
            ciphertext: ciphertext,
            nonce: nonceData,
            tag: tagData,
            tags: tags,
            networkIds: networkIds,
            validFrom: validFrom,
            validTo: validTo,
            oneTime: oneTime,
            usedAt: usedAt,
            metadata: metadata,
            createdAt: createdAt,
            updatedAt: updatedAt,
            archivedAt: archivedAt
        )
    }
}
