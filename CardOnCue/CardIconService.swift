import Foundation
import UIKit
import SwiftData

/// Service for automatically assigning and managing card icons based on business/location names
actor CardIconService {
    static let shared = CardIconService()

    private let cacheKeyPrefix = "cardIconCache_"
    private let cacheExpirationDays = 30

    private init() {}
    
    /// Analyze card name and automatically assign an appropriate icon
    /// - Parameters:
    ///   - cardName: The name of the card (e.g., "Luke's Louisville Library Card")
    ///   - locationName: Optional location name if available
    /// - Returns: SF Symbol name for the icon
    func assignIconForCard(name cardName: String, locationName: String? = nil) async -> String {
        // Extract business/location name from card name
        let businessName = extractBusinessName(from: cardName, locationName: locationName)
        
        // Check cache first
        if let cachedIcon = getCachedIcon(for: businessName) {
            return cachedIcon
        }
        
        // Determine icon based on business type and name
        let icon = determineIcon(for: businessName)
        
        // Cache the result
        cacheIcon(icon, for: businessName)
        
        return icon
    }
    
    /// Extract business/location name from card name
    /// Examples:
    /// - "Luke's Louisville Library Card" -> "Louisville Library"
    /// - "Costco Membership" -> "Costco"
    /// - "LA Fitness - Main St" -> "LA Fitness"
    private func extractBusinessName(from cardName: String, locationName: String?) -> String {
        // If location name is provided and seems like a business name, use it
        if let locationName = locationName, !locationName.isEmpty {
            // Check if location name contains business indicators
            let locationLower = locationName.lowercased()
            if !locationLower.contains("card") && !locationLower.contains("membership") {
                return locationName
            }
        }
        
        // Remove common suffixes
        var cleaned = cardName
            .replacingOccurrences(of: " Card", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " Membership", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " Member", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " Loyalty", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " Rewards", with: "", options: .caseInsensitive)
        
        // Remove possessive names (e.g., "Luke's" -> "")
        // Pattern: word ending with apostrophe-s at the start
        if let range = cleaned.range(of: "^[A-Za-z]+'s\\s+", options: .regularExpression) {
            cleaned = String(cleaned[range.upperBound...])
        }
        
        // Extract location name if present (e.g., "Louisville Library" from "Luke's Louisville Library Card")
        // Look for patterns like "City Name Business Type" or "Business Name"
        // First, try to find a pattern with a business type keyword
        let businessTypePattern = "([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)*)\\s+(Library|Gym|Fitness|Store|Market|Restaurant|Cafe|Coffee|Shop|Retail|Card|Membership|Member)"
        if let match = cleaned.range(of: businessTypePattern, options: .regularExpression) {
            let matched = String(cleaned[match])
            // Remove "Card", "Membership", "Member" suffixes
            let withoutSuffix = matched
                .replacingOccurrences(of: "\\s+Card$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+Membership$", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+Member$", with: "", options: .regularExpression)
            let result = withoutSuffix.trimmingCharacters(in: .whitespaces)
            if !result.isEmpty {
                return result
            }
        }
        
        // If no pattern matches, try to extract the main business name
        // Remove common prefixes
        let prefixes = ["My ", "The ", "A "]
        for prefix in prefixes {
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }
        
        // Split by common separators and take the first meaningful part
        let separators = [" - ", " – ", " — ", " | ", " / "]
        for separator in separators {
            if let firstPart = cleaned.components(separatedBy: separator).first {
                cleaned = firstPart.trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    /// Determine appropriate SF Symbol icon based on business name
    private func determineIcon(for businessName: String) -> String {
        let lowercased = businessName.lowercased()
        
        // Library
        if lowercased.contains("library") {
            return "book.closed.fill"
        }
        
        // Gym/Fitness
        if lowercased.contains("gym") || lowercased.contains("fitness") || 
           lowercased.contains("athletic") || lowercased.contains("sport") {
            return "figure.run"
        }
        
        // Grocery/Store
        if lowercased.contains("costco") || lowercased.contains("wholesale") {
            return "cart.fill"
        }
        if lowercased.contains("whole foods") || lowercased.contains("market") {
            return "basket.fill"
        }
        if lowercased.contains("grocery") || lowercased.contains("supermarket") {
            return "cart.fill"
        }
        
        // Retail
        if lowercased.contains("kohl") || lowercased.contains("retail") || 
           lowercased.contains("department") {
            return "bag.fill"
        }
        
        // Coffee/Cafe
        if lowercased.contains("coffee") || lowercased.contains("cafe") || 
           lowercased.contains("starbucks") {
            return "cup.and.saucer.fill"
        }
        
        // Restaurant
        if lowercased.contains("restaurant") || lowercased.contains("dining") {
            return "fork.knife"
        }
        
        // Pharmacy
        if lowercased.contains("pharmacy") || lowercased.contains("drug") || 
           lowercased.contains("cvs") || lowercased.contains("walgreens") {
            return "cross.case.fill"
        }
        
        // Gas Station
        if lowercased.contains("gas") || lowercased.contains("fuel") || 
           lowercased.contains("shell") || lowercased.contains("bp") {
            return "fuelpump.fill"
        }
        
        // Hotel
        if lowercased.contains("hotel") || lowercased.contains("resort") {
            return "bed.double.fill"
        }
        
        // Movie Theater
        if lowercased.contains("cinema") || lowercased.contains("theater") || 
           lowercased.contains("movie") {
            return "film.fill"
        }
        
        // Museum
        if lowercased.contains("museum") || lowercased.contains("gallery") {
            return "building.columns.fill"
        }
        
        // Park/Recreation
        if lowercased.contains("park") || lowercased.contains("recreation") {
            return "tree.fill"
        }
        
        // Default: credit card icon
        return "creditcard.fill"
    }
    
    /// Get cached icon for a business name (if not expired)
    private func getCachedIcon(for businessName: String) -> String? {
        let cacheKey = cacheKeyPrefix + businessName.lowercased()

        guard let cachedData = UserDefaults.standard.dictionary(forKey: cacheKey),
              let icon = cachedData["icon"] as? String,
              let cachedDate = cachedData["date"] as? Date else {
            return nil
        }
        
        // Check if cache is still valid (within 30 days)
        let daysSinceCache = Calendar.current.dateComponents([.day], from: cachedDate, to: Date()).day ?? 0
        if daysSinceCache < cacheExpirationDays {
            return icon
        }
        
        // Cache expired, remove it
        UserDefaults.standard.removeObject(forKey: cacheKey)
        return nil
    }
    
    /// Cache icon result for a business name
    private func cacheIcon(_ icon: String, for businessName: String) {
        let cacheKey = cacheKeyPrefix + businessName.lowercased()
        let cacheData: [String: Any] = [
            "icon": icon,
            "date": Date()
        ]
        UserDefaults.standard.set(cacheData, forKey: cacheKey)
    }
    
    /// Get all previously used icons (for icon selection UI)
    func getPreviouslyUsedIcons() -> [String] {
        let defaults = UserDefaults.standard
        var icons: Set<String> = []
        
        // Search through all cache entries
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix(cacheKeyPrefix) {
                if let cachedData = defaults.dictionary(forKey: key),
                   let icon = cachedData["icon"] as? String {
                    icons.insert(icon)
                }
            }
        }
        
        return Array(icons).sorted()
    }
    
    /// Clear expired cache entries
    func clearExpiredCache() {
        let defaults = UserDefaults.standard
        let keysToRemove = defaults.dictionaryRepresentation().keys.filter { key in
            if key.hasPrefix(cacheKeyPrefix) {
                if let cachedData = defaults.dictionary(forKey: key),
                   let cachedDate = cachedData["date"] as? Date {
                    let daysSinceCache = Calendar.current.dateComponents([.day], from: cachedDate, to: Date()).day ?? 0
                    return daysSinceCache >= cacheExpirationDays
                }
            }
            return false
        }

        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - URL-Based Icon Fetching

    /// Fetch brand icon/logo from a website URL
    /// Tries multiple methods: Google Favicon API, direct favicon fetch, and DuckDuckGo icons
    /// - Parameter websiteUrl: The website URL detected on the card
    /// - Returns: CardIcon with the fetched image, or nil if fetch fails
    func fetchIconFromURL(_ websiteUrl: String) async -> CardIcon? {
        // Parse domain from URL
        guard let url = URL(string: websiteUrl),
              let host = url.host else {
            return nil
        }

        // Try fetching favicon using multiple sources
        let faviconSources = [
            // Google's favicon service (most reliable)
            "https://www.google.com/s2/favicons?domain=\(host)&sz=128",
            // DuckDuckGo icon service
            "https://icons.duckduckgo.com/ip3/\(host).ico",
            // Direct favicon.ico fetch
            "https://\(host)/favicon.ico"
        ]

        for faviconURLString in faviconSources {
            if let icon = await downloadAndSaveIcon(from: faviconURLString, domain: host) {
                return icon
            }
        }

        return nil
    }

    /// Download icon from URL and save to documents directory
    private func downloadAndSaveIcon(from urlString: String, domain: String) async -> CardIcon? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Check if response is valid
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }

            // Save image to documents directory
            let fileName = "icon_\(domain)_\(UUID().uuidString).png"
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }

            let filePath = documentsPath.appendingPathComponent(fileName)

            // Convert to PNG and save
            guard let pngData = image.pngData() else { return nil }
            try pngData.write(to: filePath)

            return CardIcon.image(filePath.path)
        } catch {
            print("Failed to download icon from \(urlString): \(error)")
            return nil
        }
    }

    // MARK: - Icon Reuse from Existing Cards

    /// Find and reuse icon from existing cards with the same brand/location
    /// - Parameters:
    ///   - cardName: Name of the new card
    ///   - locationName: Optional location name
    ///   - websiteUrl: Optional website URL
    ///   - modelContext: SwiftData model context to query existing cards
    /// - Returns: Reusable CardIcon if found, nil otherwise
    func findReusableIcon(
        cardName: String,
        locationName: String?,
        websiteUrl: String?,
        modelContext: ModelContext
    ) async -> CardIcon? {
        let businessName = extractBusinessName(from: cardName, locationName: locationName)

        // Query existing cards
        let descriptor = FetchDescriptor<CardModel>()
        guard let existingCards = try? modelContext.fetch(descriptor) else {
            return nil
        }

        // Look for cards with matching business name or website URL
        for existingCard in existingCards {
            // Check if business names match
            let existingBusinessName = extractBusinessName(
                from: existingCard.name,
                locationName: existingCard.locationName
            )

            let namesMatch = businessName.lowercased() == existingBusinessName.lowercased()

            // Check if website URLs match
            var urlsMatch = false
            if let websiteUrl = websiteUrl,
               let existingWebsiteUrl = existingCard.metadata["websiteUrl"] as? String {
                urlsMatch = normalizeURL(websiteUrl) == normalizeURL(existingWebsiteUrl)
            }

            // If either match, reuse the icon (if it's a custom image)
            if namesMatch || urlsMatch {
                if let existingIcon = existingCard.getIcon(),
                   existingIcon.type == .image || existingIcon.type == .drawing {
                    return existingIcon
                }
            }
        }

        return nil
    }

    /// Normalize URL for comparison (remove protocol, www, trailing slash)
    private func normalizeURL(_ urlString: String) -> String {
        var normalized = urlString.lowercased()
        normalized = normalized.replacingOccurrences(of: "https://", with: "")
        normalized = normalized.replacingOccurrences(of: "http://", with: "")
        normalized = normalized.replacingOccurrences(of: "www.", with: "")
        normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalized
    }

    // MARK: - Manual Icon Cropping

    /// Save a cropped region from an image as a custom icon
    /// - Parameters:
    ///   - image: The source image
    ///   - cropRect: The rectangle to crop (in image coordinates)
    ///   - cardName: Name of the card (for filename)
    /// - Returns: CardIcon with the cropped image, or nil if save fails
    func saveIconFromCrop(image: UIImage, cropRect: CGRect, cardName: String) async -> CardIcon? {
        // Crop the image
        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }

        let croppedImage = UIImage(cgImage: croppedCGImage)

        // Save to documents directory
        let sanitizedName = cardName.replacingOccurrences(of: " ", with: "_")
        let fileName = "icon_\(sanitizedName)_\(UUID().uuidString).png"

        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let filePath = documentsPath.appendingPathComponent(fileName)

        do {
            // Convert to PNG and save
            guard let pngData = croppedImage.pngData() else { return nil }
            try pngData.write(to: filePath)

            return CardIcon.image(filePath.path)
        } catch {
            print("Failed to save cropped icon: \(error)")
            return nil
        }
    }
}

