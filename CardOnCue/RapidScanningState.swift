import Foundation
import SwiftUI
import SwiftData

// MARK: - Scanning Mode Enum

/// Defines the different scanning modes available in the app
enum ScanningMode: String, Codable, Sendable {
    case standard  // Existing: full review screen with all fields
    case rapid     // New: auto-save on high confidence (≥85%)
    case batch     // New: location-first multi-card scanning
}

// MARK: - Batch Location Context

/// Contains pre-selected location context for batch scanning mode
struct BatchLocationContext: Sendable {
    let locationName: String
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let icon: CardIcon?
    let phoneNumber: String?
    let website: String?
    let email: String?

    init(
        locationName: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        icon: CardIcon? = nil,
        phoneNumber: String? = nil,
        website: String? = nil,
        email: String? = nil
    ) {
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.icon = icon
        self.phoneNumber = phoneNumber
        self.website = website
        self.email = email
    }

    /// Create from SavedLocation
    static func from(_ savedLocation: SavedLocation) -> BatchLocationContext {
        return BatchLocationContext(
            locationName: savedLocation.displayName,
            latitude: savedLocation.latitude,
            longitude: savedLocation.longitude,
            address: savedLocation.address,
            icon: savedLocation.cardIcon,
            phoneNumber: savedLocation.phoneNumber,
            website: savedLocation.website,
            email: savedLocation.email
        )
    }
}

// MARK: - Auto-Saved Card Record

/// Represents a card that was auto-saved for undo/edit tracking
struct AutoSavedCard: Identifiable, Sendable {
    let id: String  // UUID of the saved card
    let name: String
    let timestamp: Date
    let confidence: Float
    var isEdited: Bool = false

    init(id: String, name: String, timestamp: Date, confidence: Float, isEdited: Bool = false) {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.confidence = confidence
        self.isEdited = isEdited
    }
}

// MARK: - Rapid Scanning State

/// Centralized state management for rapid and batch scanning modes
@Observable
class RapidScanningState {

    // MARK: - Properties

    /// Current scanning mode
    var mode: ScanningMode = .standard

    /// Batch location context (when in batch mode)
    var batchLocation: BatchLocationContext?

    /// Recently auto-saved cards (for undo/edit)
    var recentScans: [AutoSavedCard] = []

    /// Confidence threshold for auto-save (default 85%)
    var autoSaveThreshold: Float = 0.85

    /// Whether to show the auto-save toast
    var showAutoSaveToast: Bool = false

    /// Current toast card for display
    var toastCard: AutoSavedCard?

    /// Maximum number of recent scans to track
    let maxRecentScans = 10

    // MARK: - Initialization

    init(mode: ScanningMode = .standard) {
        self.mode = mode
    }

    // MARK: - Methods

    /// Add a newly auto-saved card to the recent scans stack
    func addRecentScan(_ card: AutoSavedCard) {
        recentScans.insert(card, at: 0)

        // Trim to max size
        if recentScans.count > maxRecentScans {
            recentScans.removeLast()
        }

        // Show toast
        toastCard = card
        showAutoSaveToast = true
    }

    /// Undo the most recent scan
    func undoLastScan(modelContext: ModelContext) {
        guard let lastScan = recentScans.first else { return }

        // Find and delete the card from SwiftData
        let cardIdToDelete = lastScan.id
        let descriptor = FetchDescriptor<CardModel>(
            predicate: #Predicate<CardModel> { card in
                card.id == cardIdToDelete
            }
        )

        if let cards = try? modelContext.fetch(descriptor),
           let cardToDelete = cards.first {
            modelContext.delete(cardToDelete)
            try? modelContext.save()
        }

        // Remove from recent scans
        recentScans.removeFirst()

        // Update toast
        showAutoSaveToast = false
        toastCard = nil
    }

    /// Mark a card as edited
    func markAsEdited(cardId: String) {
        if let index = recentScans.firstIndex(where: { $0.id == cardId }) {
            recentScans[index].isEdited = true
        }
    }

    /// Reset state for new scanning session
    func reset() {
        showAutoSaveToast = false
        toastCard = nil
    }

    /// Clear batch location
    func clearBatchLocation() {
        batchLocation = nil
        if mode == .batch {
            mode = .standard
        }
    }

    /// Get count of cards scanned in current batch session
    var currentBatchCount: Int {
        guard let batchLoc = batchLocation else { return 0 }

        // Count recent scans that match the batch location
        return recentScans.filter { scan in
            scan.name.contains(batchLoc.locationName)
        }.count
    }
}
