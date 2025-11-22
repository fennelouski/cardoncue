import Foundation
import CoreLocation

/// Represents a physical location (store, library branch, etc.)
struct Location: Identifiable, Codable, Hashable {
    let id: String
    let networkId: String
    var networkName: String?
    var name: String
    var address: String?
    let lat: Double
    let lon: Double
    var radiusMeters: Double
    var distanceMeters: Double?
    var phone: String?
    var hours: [String: String]?

    /// CoreLocation coordinate
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Create CLCircularRegion for monitoring
    func circularRegion(identifier: String? = nil) -> CLCircularRegion {
        let region = CLCircularRegion(
            center: coordinate,
            radius: radiusMeters,
            identifier: identifier ?? id
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        return region
    }

    /// Distance from a coordinate (in meters)
    func distance(from coordinate: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let location2 = CLLocation(latitude: lat, longitude: lon)
        return location1.distance(from: location2)
    }

    /// Human-readable distance string
    var distanceString: String? {
        guard let meters = distanceMeters else { return nil }

        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            let km = meters / 1000
            return String(format: "%.1fkm", km)
        }
    }

    /// Hours for today
    var todayHours: String? {
        guard let hours = hours else { return nil }
        let weekday = Calendar.current.component(.weekday, from: Date())
        let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        let dayName = dayNames[weekday - 1]
        return hours[dayName]
    }
}

/// Monitored region returned by region-refresh API
struct MonitoredRegion: Identifiable, Codable, Hashable {
    let id: String
    let networkId: String
    var networkName: String
    var name: String
    var address: String
    let lat: Double
    let lon: Double
    let radiusMeters: Double
    let priority: Int // 1 = user's network, 2 = other
    var distanceMeters: Double

    /// Convert to Location
    func toLocation() -> Location {
        Location(
            id: id,
            networkId: networkId,
            networkName: networkName,
            name: name,
            address: address,
            lat: lat,
            lon: lon,
            radiusMeters: radiusMeters,
            distanceMeters: distanceMeters
        )
    }

    /// Create CLCircularRegion for monitoring
    func circularRegion() -> CLCircularRegion {
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            radius: radiusMeters,
            identifier: id
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        return region
    }
}

/// Response from region-refresh API
struct RegionRefreshResponse: Codable {
    let regions: [MonitoredRegion]
    let refreshAfterMeters: Double
    let cacheTtlSeconds: Int
    let serverTime: String

    enum CodingKeys: String, CodingKey {
        case regions
        case refreshAfterMeters = "refresh_after_meters"
        case cacheTtlSeconds = "cache_ttl_seconds"
        case serverTime = "server_time"
    }
}
