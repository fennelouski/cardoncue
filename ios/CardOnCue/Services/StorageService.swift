import Foundation
import CryptoKit
import SQLite3

/// Encrypted local storage service for cards
@MainActor
class StorageService: ObservableObject {
    @Published var cards: [Card] = []

    private let keychainService: KeychainService
    private var databasePath: String
    private var db: OpaquePointer?

    enum StorageError: LocalizedError {
        case databaseNotInitialized
        case encryptionFailed
        case decryptionFailed
        case masterKeyNotFound
        case sqliteError(String)

        var errorDescription: String? {
            switch self {
            case .databaseNotInitialized:
                return "Database not initialized"
            case .encryptionFailed:
                return "Failed to encrypt card data"
            case .decryptionFailed:
                return "Failed to decrypt card data"
            case .masterKeyNotFound:
                return "Encryption key not found in Keychain"
            case .sqliteError(let message):
                return "SQLite error: \(message)"
            }
        }
    }

    init(keychainService: KeychainService) {
        self.keychainService = keychainService

        // Get database path
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        self.databasePath = documentsDirectory.appendingPathComponent("cardoncue.db").path

        // Initialize database
        Task {
            try await initializeDatabase()
            try await loadCards()
        }
    }

    // MARK: - Database Initialization

    private func initializeDatabase() async throws {
        // Open database
        if sqlite3_open(databasePath, &db) != SQLITE_OK {
            throw StorageError.sqliteError("Failed to open database")
        }

        // Enable Data Protection
        try setDataProtection()

        // Create tables
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS cards (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            barcode_type TEXT NOT NULL,
            ciphertext BLOB NOT NULL,
            nonce BLOB NOT NULL,
            tag BLOB NOT NULL,
            tags TEXT,
            network_ids TEXT,
            valid_from TEXT,
            valid_to TEXT,
            one_time INTEGER DEFAULT 0,
            used_at TEXT,
            metadata TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            archived_at TEXT
        );
        """

        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            throw StorageError.sqliteError("Failed to create tables")
        }

        print("✅ Database initialized at \(databasePath)")
    }

    private func setDataProtection() throws {
        // Set iOS Data Protection Class C (Protected Until First User Authentication)
        let attributes = [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        try FileManager.default.setAttributes(attributes, ofItemAtPath: databasePath)
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Card Operations

    /// Save a new card
    func saveCard(_ card: Card) async throws {
        // Get master key
        guard let masterKey = try keychainService.getMasterKey() else {
            throw StorageError.masterKeyNotFound
        }

        // Encrypt payload
        let encrypted = try encryptPayload(card.payload, masterKey: masterKey)

        // Insert into database
        let insertSQL = """
        INSERT INTO cards (id, user_id, name, barcode_type, ciphertext, nonce, tag, tags, network_ids, valid_from, valid_to, one_time, used_at, metadata, created_at, updated_at, archived_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.sqliteError("Failed to prepare statement")
        }

        // Bind values
        sqlite3_bind_text(statement, 1, (card.id as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (card.userId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (card.name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 4, (card.barcodeType.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_blob(statement, 5, (encrypted.ciphertext as NSData).bytes, Int32(encrypted.ciphertext.count), nil)
        sqlite3_bind_blob(statement, 6, (encrypted.nonce as NSData).bytes, Int32(encrypted.nonce.count), nil)
        sqlite3_bind_blob(statement, 7, (encrypted.tag as NSData).bytes, Int32(encrypted.tag.count), nil)
        sqlite3_bind_text(statement, 8, (try JSONEncoder().encode(card.tags) as NSData).bytes as! UnsafePointer<Int8>?, -1, nil)
        sqlite3_bind_text(statement, 9, (try JSONEncoder().encode(card.networkIds) as NSData).bytes as! UnsafePointer<Int8>?, -1, nil)

        // Dates and metadata omitted for brevity - use ISO8601 format

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StorageError.sqliteError("Failed to insert card")
        }

        // Add to local array
        cards.append(card)

        print("✅ Card saved: \(card.name)")
    }

    /// Get all cards
    func getAllCards() async throws -> [Card] {
        return cards
    }

    /// Get card by ID
    func getCard(id: String) async throws -> Card? {
        return cards.first { $0.id == id }
    }

    /// Update card
    func updateCard(_ card: Card) async throws {
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
        }
        // TODO: Update in database
    }

    /// Delete card
    func deleteCard(id: String) async throws {
        if let index = cards.firstIndex(where: { $0.id == id }) {
            cards.remove(at: index)
        }
        // TODO: Soft delete in database
    }

    // MARK: - Loading

    private func loadCards() async throws {
        guard let masterKey = try keychainService.getMasterKey() else {
            print("⚠️ No master key found, generating new one")
            _ = try keychainService.generateAndStoreMasterKey()
            return
        }

        let selectSQL = "SELECT * FROM cards WHERE archived_at IS NULL;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK else {
            throw StorageError.sqliteError("Failed to prepare query")
        }

        var loadedCards: [Card] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            do {
                let card = try parseCardRow(statement!, masterKey: masterKey)
                loadedCards.append(card)
            } catch {
                print("⚠️ Failed to parse card: \(error)")
            }
        }

        cards = loadedCards
        print("✅ Loaded \(cards.count) cards")
    }

    private func parseCardRow(_ statement: OpaquePointer, masterKey: SymmetricKey) throws -> Card {
        let id = String(cString: sqlite3_column_text(statement, 0))
        let userId = String(cString: sqlite3_column_text(statement, 1))
        let name = String(cString: sqlite3_column_text(statement, 2))
        let barcodeTypeRaw = String(cString: sqlite3_column_text(statement, 3))
        let barcodeType = BarcodeType(rawValue: barcodeTypeRaw)!

        // Get encrypted data
        let ciphertextBytes = sqlite3_column_blob(statement, 4)
        let ciphertextLen = sqlite3_column_bytes(statement, 4)
        let ciphertext = Data(bytes: ciphertextBytes!, count: Int(ciphertextLen))

        let nonceBytes = sqlite3_column_blob(statement, 5)
        let nonceLen = sqlite3_column_bytes(statement, 5)
        let nonce = Data(bytes: nonceBytes!, count: Int(nonceLen))

        let tagBytes = sqlite3_column_blob(statement, 6)
        let tagLen = sqlite3_column_bytes(statement, 6)
        let tag = Data(bytes: tagBytes!, count: Int(tagLen))

        // Decrypt payload
        let payload = try decryptPayload(ciphertext: ciphertext, nonce: nonce, tag: tag, masterKey: masterKey)

        // Parse remaining fields...
        return Card(
            id: id,
            userId: userId,
            name: name,
            barcodeType: barcodeType,
            payload: payload,
            tags: [],
            networkIds: [],
            validFrom: nil,
            validTo: nil,
            oneTime: false,
            usedAt: nil,
            metadata: [:],
            createdAt: Date(),
            updatedAt: Date(),
            archivedAt: nil
        )
    }

    // MARK: - Encryption/Decryption

    private func encryptPayload(_ payload: String, masterKey: SymmetricKey) throws -> (ciphertext: Data, nonce: Data, tag: Data) {
        guard let data = payload.data(using: .utf8) else {
            throw StorageError.encryptionFailed
        }

        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: masterKey, nonce: nonce)

        return (
            ciphertext: sealedBox.ciphertext,
            nonce: nonce.dataRepresentation,
            tag: sealedBox.tag
        )
    }

    private func decryptPayload(ciphertext: Data, nonce: Data, tag: Data, masterKey: SymmetricKey) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(
            nonce: AES.GCM.Nonce(data: nonce),
            ciphertext: ciphertext,
            tag: tag
        )

        let decrypted = try AES.GCM.open(sealedBox, using: masterKey)

        guard let payload = String(data: decrypted, encoding: .utf8) else {
            throw StorageError.decryptionFailed
        }

        return payload
    }
}
