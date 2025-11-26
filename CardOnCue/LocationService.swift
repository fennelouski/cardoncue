import Foundation
import CoreLocation
import Combine

/// Location monitoring service with dynamic region refresh
@MainActor
class LocationService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var monitoredRegions: [MonitoredRegion] = []
    @Published var isMonitoring = false
    @Published var lastRefreshDate: Date?
    @Published var lastError: Error?

    // MARK: - Constants

    private let regionLimit = 20
    private let refreshThresholdMeters: CLLocationDistance = 500.0
    private let refreshIntervalSeconds: TimeInterval = 21600 // 6 hours
    private let coarseAccuracy = kCLLocationAccuracyHundredMeters

    // MARK: - Dependencies

    private let locationManager = CLLocationManager()
    private var apiClient: APIClient?
    private var storageService: StorageService?

    // MARK: - State

    private var lastRefreshLocation: CLLocation?
    private var refreshTask: Task<Void, Never>?

    // MARK: - Callbacks

    var onRegionEnter: ((MonitoredRegion) -> Void)?
    var onRegionExit: ((MonitoredRegion) -> Void)?

    enum LocationError: LocalizedError {
        case permissionDenied
        case locationUnavailable
        case refreshFailed
        case apiClientNotSet

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Location permission denied. Please enable in Settings."
            case .locationUnavailable:
                return "Unable to determine current location"
            case .refreshFailed:
                return "Failed to refresh monitored regions"
            case .apiClientNotSet:
                return "API client not configured"
            }
        }
    }

    // MARK: - Initialization

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = coarseAccuracy
        locationManager.distanceFilter = 100 // Update every 100m
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func configure(apiClient: APIClient, storageService: StorageService) {
        self.apiClient = apiClient
        self.storageService = storageService
    }

    // MARK: - Permission Management

    /// Request location permission
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Request always permission (for background monitoring)
    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Monitoring Control

    /// Start location monitoring and region refresh
    func startMonitoring() async throws {
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            throw LocationError.permissionDenied
        }

        // Start location updates
        locationManager.startUpdatingLocation()

        // Start monitoring significant location changes (for background)
        locationManager.startMonitoringSignificantLocationChanges()

        // Start visit monitoring (for stationary periods)
        locationManager.startMonitoringVisits()

        isMonitoring = true

        // Perform initial region refresh
        try await refreshRegionsIfNeeded(force: true)
    }

    /// Stop all location monitoring
    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopMonitoringVisits()

        // Stop monitoring all regions
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }

        isMonitoring = false
        monitoredRegions = []
    }

    // MARK: - Region Refresh Logic

    /// Check if regions need to be refreshed
    func shouldRefreshRegions(for location: CLLocation) -> Bool {
        // Check distance threshold
        if let last = lastRefreshLocation {
            let distance = location.distance(from: last)
            if distance < refreshThresholdMeters {
                return false
            }
        }

        // Check time threshold
        if let lastTime = lastRefreshDate {
            if Date().timeIntervalSince(lastTime) < refreshIntervalSeconds {
                return false
            }
        }

        return true
    }

    /// Refresh monitored regions if needed
    func refreshRegionsIfNeeded(force: Bool = false) async throws {
        guard let location = currentLocation ?? locationManager.location else {
            throw LocationError.locationUnavailable
        }

        if !force && !shouldRefreshRegions(for: location) {
            return
        }

        try await refreshMonitoredRegions(near: location)
    }

    /// Refresh monitored regions from server
    private func refreshMonitoredRegions(near location: CLLocation) async throws {
        guard let apiClient = apiClient else {
            throw LocationError.apiClientNotSet
        }

        // Get user's networks from storage
        let userNetworks = await getUserNetworkIds()

        // Call region-refresh API
        let request = RegionRefreshRequest(
            lat: location.coordinate.latitude,
            lon: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            radiusKm: 50,
            userNetworks: userNetworks,
            maxRegions: regionLimit
        )

        do {
            let response = try await apiClient.refreshRegions(request)

            // Stop monitoring old regions
            for region in locationManager.monitoredRegions {
                locationManager.stopMonitoring(for: region)
            }

            // Start monitoring new regions
            for regionData in response.regions {
                let region = regionData.circularRegion()
                locationManager.startMonitoring(for: region)
            }

            // Update state
            monitoredRegions = response.regions
            lastRefreshLocation = location
            lastRefreshDate = Date()

            print("✅ Refreshed regions: \(response.regions.count) regions monitored")

        } catch {
            lastError = error
            throw LocationError.refreshFailed
        }
    }

    private func getUserNetworkIds() async -> [String] {
        guard let storageService = storageService else { return [] }

        do {
            let cards = try await storageService.getAllCards()
            let networkIds = Set(cards.flatMap { $0.networkIds })
            return Array(networkIds)
        } catch {
            print("⚠️ Failed to get user networks: \(error)")
            return []
        }
    }

    // MARK: - Manual Region Refresh

    /// Force refresh regions now
    func forceRefresh() async throws {
        try await refreshRegionsIfNeeded(force: true)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            self.currentLocation = location

            // Check if we should refresh regions
            do {
                try await self.refreshRegionsIfNeeded()
            } catch {
                print("⚠️ Failed to refresh regions: \(error)")
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        Task { @MainActor in
            print("📍 Entered region: \(circularRegion.identifier)")

            // Find matching monitored region
            if let monitoredRegion = self.monitoredRegions.first(where: { $0.id == circularRegion.identifier }) {
                self.onRegionEnter?(monitoredRegion)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }

        Task { @MainActor in
            print("📍 Exited region: \(circularRegion.identifier)")

            // Find matching monitored region
            if let monitoredRegion = self.monitoredRegions.first(where: { $0.id == circularRegion.identifier }) {
                self.onRegionExit?(monitoredRegion)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Task { @MainActor in
            print("❌ Monitoring failed for region: \(region?.identifier ?? "unknown"), error: \(error)")
            self.lastError = error
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("❌ Location manager failed: \(error)")
            self.lastError = error
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Task { @MainActor in
            print("📍 Visit detected: \(visit.coordinate.latitude), \(visit.coordinate.longitude)")

            // Trigger region refresh when user visits a location
            do {
                try await self.refreshRegionsIfNeeded()
            } catch {
                print("⚠️ Failed to refresh on visit: \(error)")
            }
        }
    }
}

// MARK: - Region Refresh Request

struct RegionRefreshRequest: Codable {
    let lat: Double
    let lon: Double
    let accuracy: Double
    let radiusKm: Double
    let userNetworks: [String]
    let maxRegions: Int

    enum CodingKeys: String, CodingKey {
        case lat
        case lon
        case accuracy
        case radiusKm = "radius_km"
        case userNetworks = "user_networks"
        case maxRegions = "max_regions"
    }
}
