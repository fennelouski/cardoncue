import Foundation

/// Offline Tier 1 brand registry loaded from bundled JSON snapshot.
struct BrandRegistryEntry: Codable, Sendable {
    let name: String
    let displayName: String
    let domain: String?
    let category: String?
    let logoUrl: String?
    let verified: Bool
}

struct BrandRegistrySnapshotFile: Codable {
    let generatedAt: String
    let count: Int
    let brands: [BrandRegistryEntry]
}

enum BrandRegistrySnapshot {
    private static let loadedEntries: [BrandRegistryEntry] = {
        guard let url = Bundle.main.url(forResource: "brand_registry_snapshot", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(BrandRegistrySnapshotFile.self, from: data) else {
            return []
        }
        return file.brands
    }()

    private static let entriesByName: [String: BrandRegistryEntry] = {
        var map: [String: BrandRegistryEntry] = [:]
        for entry in loadedEntries {
            map[entry.name] = entry
            map[BrandDomainResolver.normalizeBrandName(entry.displayName)] = entry
            map[BrandDomainResolver.normalizeBrandAlias(entry.displayName)] = entry
        }
        return map
    }()

    static func lookup(cardName: String, locationName: String?) -> BrandRegistryEntry? {
        let candidates = [
            CardModel.extractBrandName(from: cardName, locationName: locationName),
            locationName,
            cardName
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for candidate in candidates {
            let keys = [
                BrandDomainResolver.normalizeBrandName(candidate),
                BrandDomainResolver.normalizeBrandAlias(candidate)
            ]
            for key in keys where !key.isEmpty {
                if let entry = entriesByName[key] {
                    return entry
                }
            }
        }

        return nil
    }

    static func lookup(domain: String) -> BrandRegistryEntry? {
        let normalized = domain.lowercased().replacingOccurrences(of: "www.", with: "")
        return loadedEntries.first {
            ($0.domain ?? "").lowercased().replacingOccurrences(of: "www.", with: "") == normalized
        }
    }
}
