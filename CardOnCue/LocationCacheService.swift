import Foundation
import SwiftData
import CoreLocation

class LocationCacheService {
    static let shared = LocationCacheService()

    private init() {}

    // MARK: - Public Methods

    /// Save or update a location in the cache
    func saveLocation(
        name: String,
        address: String?,
        latitude: Double?,
        longitude: Double?,
        phoneNumber: String? = nil,
        website: String? = nil,
        email: String? = nil,
        hours: String? = nil,
        socialMedia: String? = nil,
        notes: String? = nil,
        icon: CardIcon? = nil,
        context: ModelContext
    ) {
        guard !name.isEmpty else { return }

        let normalizedName = normalize(name)

        // Check if location already exists
        let descriptor = FetchDescriptor<SavedLocation>(
            predicate: #Predicate { location in
                location.name == normalizedName
            }
        )

        do {
            let existingLocations = try context.fetch(descriptor)

            // Check for exact match (same name and address/coordinates)
            let exactMatch = existingLocations.first { location in
                // Match if addresses are the same (when both exist)
                if let addr1 = location.address, let addr2 = address,
                   normalize(addr1) == normalize(addr2) {
                    return true
                }

                // Match if coordinates are very close (within ~10 meters)
                if let lat1 = location.latitude, let lon1 = location.longitude,
                   let lat2 = latitude, let lon2 = longitude {
                    let distance = CLLocation(latitude: lat1, longitude: lon1)
                        .distance(from: CLLocation(latitude: lat2, longitude: lon2))
                    return distance < 10
                }

                // If neither address nor coordinates match, it's a different location
                return false
            }

            if let existing = exactMatch {
                // Update existing location with new data (prefer new data if available)
                existing.displayName = name  // Update to latest display name
                existing.address = address ?? existing.address
                existing.latitude = latitude ?? existing.latitude
                existing.longitude = longitude ?? existing.longitude
                existing.phoneNumber = phoneNumber ?? existing.phoneNumber
                existing.website = website ?? existing.website
                existing.email = email ?? existing.email
                existing.hours = hours ?? existing.hours
                existing.socialMedia = socialMedia ?? existing.socialMedia
                existing.notes = notes ?? existing.notes

                // Update icon data if provided
                if let icon = icon {
                    existing.cardIcon = icon
                }

                existing.lastUsedDate = Date()
                existing.usageCount += 1
            } else {
                // Create new location
                let newLocation = SavedLocation(
                    name: normalizedName,
                    displayName: name,
                    address: address,
                    latitude: latitude,
                    longitude: longitude,
                    phoneNumber: phoneNumber,
                    website: website,
                    hours: hours,
                    email: email,
                    socialMedia: socialMedia,
                    notes: notes,
                    iconType: icon?.type.rawValue,
                    iconValue: icon?.value,
                    iconColorHex: icon?.colorHex,
                    iconBackgroundColorHex: icon?.backgroundColorHex
                )
                context.insert(newLocation)
            }

            try context.save()
        } catch {
            print("Error saving location to cache: \(error)")
        }
    }

    /// Find cached locations matching the given name or address
    func findMatches(
        for searchName: String?,
        address searchAddress: String?,
        userLocation: CLLocationCoordinate2D?,
        context: ModelContext
    ) -> [SavedLocation] {
        let descriptor = FetchDescriptor<SavedLocation>()

        do {
            let allLocations = try context.fetch(descriptor)
            var matches: [(location: SavedLocation, score: Double)] = []

            for location in allLocations {
                var score: Double = 0.0

                // Name matching
                if let searchName = searchName, !searchName.isEmpty {
                    let nameScore = matchScore(
                        search: normalize(searchName),
                        candidate: location.name
                    )
                    score = max(score, nameScore)
                }

                // Address matching
                if let searchAddress = searchAddress,
                   !searchAddress.isEmpty,
                   let locationAddress = location.address {
                    let addressScore = matchScore(
                        search: normalize(searchAddress),
                        candidate: normalize(locationAddress)
                    )
                    score = max(score, addressScore)
                }

                // Only include if score is above threshold
                if score >= 0.5 {
                    matches.append((location, score))
                }
            }

            // Sort by score (high to low), then by distance (if available), then by last used
            let sorted = matches.sorted { match1, match2 in
                // Primary sort: match score
                if abs(match1.score - match2.score) > 0.01 {
                    return match1.score > match2.score
                }

                // Secondary sort: distance from user
                if let userLocation = userLocation {
                    let dist1 = match1.location.distance(from: userLocation) ?? Double.infinity
                    let dist2 = match2.location.distance(from: userLocation) ?? Double.infinity
                    if abs(dist1 - dist2) > 1.0 {  // More than 1 meter difference
                        return dist1 < dist2
                    }
                }

                // Tertiary sort: last used date
                return match1.location.lastUsedDate > match2.location.lastUsedDate
            }

            return sorted.map { $0.location }
        } catch {
            print("Error fetching cached locations: \(error)")
            return []
        }
    }

    /// Update usage statistics for a location
    func updateUsage(for location: SavedLocation, context: ModelContext) {
        location.lastUsedDate = Date()
        location.usageCount += 1

        do {
            try context.save()
        } catch {
            print("Error updating location usage: \(error)")
        }
    }

    // MARK: - Private Helpers

    /// Normalize string for fuzzy matching
    private func normalize(_ string: String) -> String {
        // Convert to lowercase
        var normalized = string.lowercased()

        // Remove common punctuation
        let punctuation = CharacterSet(charactersIn: ".,;:!?-—–()[]{}\"'`")
        normalized = normalized.components(separatedBy: punctuation).joined()

        // Replace multiple spaces with single space
        normalized = normalized.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // Trim whitespace
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized
    }

    /// Calculate fuzzy match score between search string and candidate
    /// Returns 0.0 (no match) to 1.0 (exact match)
    private func matchScore(search: String, candidate: String) -> Double {
        // Exact match
        if search == candidate {
            return 1.0
        }

        // Contains match
        if candidate.contains(search) {
            return 0.8
        }

        // Reverse contains (search contains candidate)
        if search.contains(candidate) {
            return 0.7
        }

        // Levenshtein distance-based matching
        let distance = levenshteinDistance(search, candidate)
        let maxLength = Double(max(search.count, candidate.count))

        // Calculate similarity ratio (1.0 - normalized distance)
        let similarity = 1.0 - (Double(distance) / maxLength)

        // Apply threshold - below 0.5 similarity is not a match
        return similarity >= 0.5 ? similarity : 0.0
    }

    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)

        var matrix = [[Int]](
            repeating: [Int](repeating: 0, count: s2Array.count + 1),
            count: s1Array.count + 1
        )

        for i in 0...s1Array.count {
            matrix[i][0] = i
        }

        for j in 0...s2Array.count {
            matrix[0][j] = j
        }

        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                if s1Array[i - 1] == s2Array[j - 1] {
                    matrix[i][j] = matrix[i - 1][j - 1]
                } else {
                    matrix[i][j] = min(
                        matrix[i - 1][j] + 1,      // deletion
                        matrix[i][j - 1] + 1,      // insertion
                        matrix[i - 1][j - 1] + 1   // substitution
                    )
                }
            }
        }

        return matrix[s1Array.count][s2Array.count]
    }
}
