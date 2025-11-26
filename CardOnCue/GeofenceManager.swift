import Foundation
import CoreLocation
import SwiftData
import UserNotifications
import Combine

/// Manages smart geofence rotation - monitors 20 nearest locations intelligently
@MainActor
final class GeofenceManager: NSObject, ObservableObject {
    static let shared = GeofenceManager()

    private let locationManager = CLLocationManager()
    private var modelContext: ModelContext?

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isMonitoring = false
    @Published var currentLocation: CLLocation?

    // Constants
    private let maxGeofences = 20 // iOS limit
    private let significantDistanceThreshold = 5000.0 // 5km - when to refresh geofences

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update every 100m
        authorizationStatus = locationManager.authorizationStatus
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Permission Handling

    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Optionally upgrade to Always for background monitoring
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startMonitoring()
        case .denied, .restricted:
            print("⚠️ Location permission denied")
        @unknown default:
            break
        }
    }

    // MARK: - Monitoring Control

    func startMonitoring() {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            print("⚠️ Location permission not granted")
            return
        }

        // Start monitoring significant location changes (battery efficient)
        locationManager.startMonitoringSignificantLocationChanges()

        // Also get current location updates
        locationManager.startUpdatingLocation()

        isMonitoring = true
        print("✅ Started location monitoring")
    }

    func stopMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopUpdatingLocation()

        // Remove all geofences
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }

        isMonitoring = false
        print("🛑 Stopped location monitoring")
    }

    // MARK: - Smart Geofence Rotation

    private func updateActiveGeofences(near location: CLLocation) {
        guard let modelContext = modelContext else {
            print("⚠️ ModelContext not configured")
            return
        }

        do {
            // Fetch all cards with locations
            let descriptor = FetchDescriptor<CardModel>(
                predicate: #Predicate { card in
                    card.locationLatitude != nil && card.archivedAt == nil
                }
            )
            let cardsWithLocations = try modelContext.fetch(descriptor)

            // Calculate distances and sort by nearest
            let cardsWithDistances = cardsWithLocations.compactMap { card -> (CardModel, Double)? in
                guard let lat = card.locationLatitude,
                      let lon = card.locationLongitude else { return nil }

                let cardLocation = CLLocation(latitude: lat, longitude: lon)
                let distance = location.distance(from: cardLocation)
                return (card, distance)
            }
            .sorted { $0.1 < $1.1 } // Sort by distance

            // Select the 20 nearest
            let nearest20 = Array(cardsWithDistances.prefix(maxGeofences))

            // Mark which cards should be actively monitored
            for card in cardsWithLocations {
                let shouldBeActive = nearest20.contains { $0.0.id == card.id }
                if card.isGeofenceActive != shouldBeActive {
                    card.isGeofenceActive = shouldBeActive
                }
            }

            try modelContext.save()

            // Update iOS geofences
            updateIOSGeofences(for: nearest20.map { $0.0 })

            print("✅ Updated geofences: monitoring \(nearest20.count) locations")

        } catch {
            print("❌ Failed to update geofences: \(error)")
        }
    }

    private func updateIOSGeofences(for cards: [CardModel]) {
        // Remove all existing geofences
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }

        // Add new geofences
        for card in cards {
            guard let lat = card.locationLatitude,
                  let lon = card.locationLongitude else { continue }

            let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let region = CLCircularRegion(
                center: center,
                radius: card.locationRadius,
                identifier: card.id
            )

            region.notifyOnEntry = true
            region.notifyOnExit = false // Only notify on entry

            locationManager.startMonitoring(for: region)
            print("📍 Monitoring geofence for: \(card.name)")
        }
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied")
            }
        }
    }

    private func sendLocationNotification(for card: CardModel) {
        let content = UNMutableNotificationContent()
        content.title = "📍 You're near \(card.locationName ?? card.name)"
        content.body = "Tap to open your \(card.name) card"
        content.sound = .default
        content.userInfo = ["cardId": card.id]

        let request = UNNotificationRequest(
            identifier: "geofence_\(card.id)",
            content: content,
            trigger: nil // Deliver immediately
        )

        // Capture only what's needed to avoid Sendable issue
        let cardName = card.name
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                print("✅ Sent notification for: \(cardName)")
            }
        }
    }

    // MARK: - Helper Methods

    func getCard(for identifier: String) -> CardModel? {
        guard let modelContext = modelContext else { return nil }

        do {
            let descriptor = FetchDescriptor<CardModel>(
                predicate: #Predicate { card in
                    card.id == identifier
                }
            )
            return try modelContext.fetch(descriptor).first
        } catch {
            print("❌ Failed to fetch card: \(error)")
            return nil
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension GeofenceManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus

            if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
                startMonitoring()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let newLocation = locations.last else { return }

            // Check if user has moved significantly
            let shouldUpdate: Bool
            if let current = currentLocation {
                let distance = newLocation.distance(from: current)
                shouldUpdate = distance > significantDistanceThreshold
            } else {
                shouldUpdate = true // First location
            }

            currentLocation = newLocation

            if shouldUpdate {
                print("📍 Significant location change detected, updating geofences...")
                updateActiveGeofences(near: newLocation)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            guard let circularRegion = region as? CLCircularRegion,
                  let card = getCard(for: circularRegion.identifier) else { return }

            print("✅ Entered geofence for: \(card.name)")

            // Send notification
            sendLocationNotification(for: card)

            // Update last used timestamp (optional)
            card.metadata["lastGeofenceEntry"] = ISO8601DateFormatter().string(from: Date())
            card.updatedAt = Date()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            guard let circularRegion = region as? CLCircularRegion,
                  let card = getCard(for: circularRegion.identifier) else { return }

            print("🚶 Exited geofence for: \(card.name)")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Task { @MainActor in
            print("❌ Geofence monitoring failed for \(region?.identifier ?? "unknown"): \(error)")
        }
    }
}
