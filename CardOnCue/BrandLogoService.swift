import Foundation
import UIKit

/// Downloads and caches brand logo images from remote URLs (Logo.dev, favicons, registry CDN).
actor BrandLogoService {
    static let shared = BrandLogoService()

    private var logoCache: [String: LogoCacheEntry] = [:]
    private let imageCache = NSCache<NSString, UIImage>()
    private let logosDirectory: URL

    struct LogoCacheEntry {
        let logoURL: URL?
        let domain: String
        let fetchedAt: Date
        let isValid: Bool
    }

    private init() {
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        logosDirectory = documentsPath.appendingPathComponent("BrandLogos", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: logosDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )

        imageCache.countLimit = 50
        imageCache.totalCostLimit = 20 * 1024 * 1024
    }

    /// Fetch logo via Logo.dev for a brand name (local fallback when API is unavailable).
    func fetchLogoIcon(for brandName: String) async -> CardIcon? {
        let domain = BrandDomainResolver.determineDomain(for: brandName)
        let logoURL = logoDevURL(for: domain)
        return await downloadLogoIcon(from: logoURL, cacheKey: brandName.lowercased())
    }

    /// Legacy UIImage fetch used by older call sites.
    func fetchLogo(for brandName: String) async -> UIImage? {
        guard let icon = await fetchLogoIcon(for: brandName),
              icon.type == .image else {
            return nil
        }
        return UIImage(contentsOfFile: icon.value)
    }

    /// Download a remote logo URL and persist it as a CardIcon image.
    func downloadLogoIcon(from urlString: String, cacheKey: String) async -> CardIcon? {
        let normalizedKey = cacheKey.lowercased()

        if let cached = logoCache[normalizedKey] {
            let age = Date().timeIntervalSince(cached.fetchedAt)
            if age < 7 * 24 * 3600 {
                if !cached.isValid { return nil }
                if await loadCachedLogo(brandName: normalizedKey) != nil {
                    let filename = "\(normalizedKey.replacingOccurrences(of: " ", with: "_"))_logo.png"
                    let fileURL = logosDirectory.appendingPathComponent(filename)
                    return CardIcon.image(fileURL.path)
                }
            }
        }

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                logoCache[normalizedKey] = LogoCacheEntry(
                    logoURL: nil,
                    domain: BrandDomainResolver.determineDomain(for: cacheKey),
                    fetchedAt: Date(),
                    isValid: false
                )
                return nil
            }

            let filename = "\(normalizedKey.replacingOccurrences(of: " ", with: "_"))_logo.png"
            let fileURL = logosDirectory.appendingPathComponent(filename)

            if let pngData = image.pngData() {
                try? pngData.write(to: fileURL, options: [.atomic, .completeFileProtection])
            }

            let cost = Int(image.size.width * image.size.height * 4)
            imageCache.setObject(image, forKey: normalizedKey as NSString, cost: cost)
            logoCache[normalizedKey] = LogoCacheEntry(
                logoURL: fileURL,
                domain: BrandDomainResolver.determineDomain(for: cacheKey),
                fetchedAt: Date(),
                isValid: true
            )

            return CardIcon.image(fileURL.path)
        } catch {
            logoCache[normalizedKey] = LogoCacheEntry(
                logoURL: nil,
                domain: BrandDomainResolver.determineDomain(for: cacheKey),
                fetchedAt: Date(),
                isValid: false
            )
            return nil
        }
    }

    private func loadCachedLogo(brandName: String) async -> UIImage? {
        let cacheKey = brandName.lowercased() as NSString

        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }

        let filename = "\(brandName.lowercased().replacingOccurrences(of: " ", with: "_"))_logo.png"
        let fileURL = logosDirectory.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        let cost = Int(image.size.width * image.size.height * 4)
        imageCache.setObject(image, forKey: cacheKey, cost: cost)
        return image
    }

    private func logoDevURL(for domain: String) -> String {
        if let token = Bundle.main.object(forInfoDictionaryKey: "LOGO_DEV_TOKEN") as? String,
           !token.isEmpty {
            return "https://img.logo.dev/\(domain)?token=\(token)"
        }
        return "https://img.logo.dev/\(domain)"
    }

    func clearExpiredCache() {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        logoCache = logoCache.filter { $0.value.fetchedAt > cutoff }
    }

    func clearAllCache() {
        logoCache.removeAll()
        imageCache.removeAllObjects()
        try? FileManager.default.removeItem(at: logosDirectory)
        try? FileManager.default.createDirectory(
            at: logosDirectory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
    }
}
