import Foundation
import UIKit

/// Actor-based service for fetching and caching brand logos from Clearbit Logo API
actor BrandLogoService {
    static let shared = BrandLogoService()

    // Memory cache for logo URLs and metadata
    private var logoCache: [String: LogoCacheEntry] = [:]
    private let imageCache = NSCache<NSString, UIImage>()
    private let logosDirectory: URL

    struct LogoCacheEntry {
        let logoURL: URL?  // nil if fetch failed
        let domain: String
        let fetchedAt: Date
        let isValid: Bool
    }

    private init() {
        // Create logos directory
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        logosDirectory = documentsPath.appendingPathComponent("BrandLogos", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: logosDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )

        // Configure image cache
        imageCache.countLimit = 50  // More logos than card images
        imageCache.totalCostLimit = 20 * 1024 * 1024  // 20 MB
    }

    /// Fetch logo for a brand (with caching)
    func fetchLogo(for brandName: String) async -> UIImage? {
        let cacheKey = brandName.lowercased()

        // Check memory cache
        if let cached = logoCache[cacheKey] {
            // Cache valid for 7 days
            let age = Date().timeIntervalSince(cached.fetchedAt)
            if age < 7 * 24 * 3600 {
                if !cached.isValid {
                    return nil  // Previously failed
                }
                // Try to load from disk or memory
                return await loadCachedLogo(brandName: brandName, domain: cached.domain)
            }
        }

        // Determine domain
        let domain = determineDomain(for: brandName)

        // Fetch from Clearbit
        let clearbitURL = URL(string: "https://logo.clearbit.com/\(domain)")!

        do {
            let (data, response) = try await URLSession.shared.data(from: clearbitURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                // Logo not found
                logoCache[cacheKey] = LogoCacheEntry(
                    logoURL: nil,
                    domain: domain,
                    fetchedAt: Date(),
                    isValid: false
                )
                return nil
            }

            // Save to disk
            let filename = "\(cacheKey.replacingOccurrences(of: " ", with: "_"))_logo.png"
            let fileURL = logosDirectory.appendingPathComponent(filename)

            if let pngData = image.pngData() {
                try? pngData.write(to: fileURL, options: [.atomic, .completeFileProtection])
            }

            // Cache in memory
            let cost = Int(image.size.width * image.size.height * 4) // Estimate bytes
            imageCache.setObject(image, forKey: cacheKey as NSString, cost: cost)
            logoCache[cacheKey] = LogoCacheEntry(
                logoURL: fileURL,
                domain: domain,
                fetchedAt: Date(),
                isValid: true
            )

            return image

        } catch {
            // Network error or invalid response
            logoCache[cacheKey] = LogoCacheEntry(
                logoURL: nil,
                domain: domain,
                fetchedAt: Date(),
                isValid: false
            )
            return nil
        }
    }

    private func loadCachedLogo(brandName: String, domain: String) async -> UIImage? {
        let cacheKey = brandName.lowercased() as NSString

        // Check memory cache
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        // Check disk cache
        let filename = "\(brandName.lowercased().replacingOccurrences(of: " ", with: "_"))_logo.png"
        let fileURL = logosDirectory.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        // Cache in memory
        let cost = Int(image.size.width * image.size.height * 4)
        imageCache.setObject(image, forKey: cacheKey, cost: cost)
        return image
    }

    /// Determine domain from brand name
    private func determineDomain(for brandName: String) -> String {
        let normalized = brandName.lowercased().trimmingCharacters(in: .whitespaces)

        // Special mappings for known brands
        let specialMappings: [String: String] = [
            "costco": "costco.com",
            "costco wholesale": "costco.com",
            "sam's club": "samsclub.com",
            "sams club": "samsclub.com",
            "bj's": "bjs.com",
            "bj's wholesale": "bjs.com",
            "bjs": "bjs.com",
            "bjs wholesale": "bjs.com",
            "whole foods": "wholefoodsmarket.com",
            "whole foods market": "wholefoodsmarket.com",
            "trader joe's": "traderjoes.com",
            "trader joes": "traderjoes.com",
            "kohl's": "kohls.com",
            "kohls": "kohls.com",
            "macy's": "macys.com",
            "macys": "macys.com",
            "target": "target.com",
            "walmart": "walmart.com",
            "cvs": "cvs.com",
            "cvs pharmacy": "cvs.com",
            "walgreens": "walgreens.com",
            "la fitness": "lafitness.com",
            "24 hour fitness": "24hourfitness.com",
            "planet fitness": "planetfitness.com",
            "anytime fitness": "anytimefitness.com",
            "gold's gym": "goldsgym.com",
            "golds gym": "goldsgym.com",
            "starbucks": "starbucks.com",
            "dunkin": "dunkindonuts.com",
            "dunkin donuts": "dunkindonuts.com",
            "kroger": "kroger.com",
            "safeway": "safeway.com",
            "albertsons": "albertsons.com",
            "publix": "publix.com",
            "best buy": "bestbuy.com",
            "home depot": "homedepot.com",
            "lowe's": "lowes.com",
            "lowes": "lowes.com",
            "amc": "amctheatres.com",
            "regal": "regmovies.com",
            "cinemark": "cinemark.com",
            "panera": "panerabread.com",
            "panera bread": "panerabread.com",
            "chipotle": "chipotle.com"
        ]

        if let mapped = specialMappings[normalized] {
            return mapped
        }

        // Generic mapping: remove spaces, apostrophes, hyphens, add .com
        let domain = normalized
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "-", with: "")

        return "\(domain).com"
    }

    /// Clear expired cache entries
    func clearExpiredCache() {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)  // 7 days ago
        logoCache = logoCache.filter { $0.value.fetchedAt > cutoff }
    }

    /// Clear all cached logos
    func clearAllCache() {
        logoCache.removeAll()
        imageCache.removeAllObjects()

        // Remove disk cache
        try? FileManager.default.removeItem(at: logosDirectory)
        try? FileManager.default.createDirectory(
            at: logosDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
    }
}
