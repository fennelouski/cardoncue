import Foundation
import SwiftData
import UIKit

/// Unified tiered resolver for membership/business card icons.
actor MembershipIconResolver {
    static let shared = MembershipIconResolver()

    private init() {}

    /// Resolve the best icon using the full cascade.
    func resolveIcon(
        cardName: String,
        locationName: String? = nil,
        websiteUrl: String? = nil,
        existingIcon: CardIcon? = nil,
        cachedLocationIcon: CardIcon? = nil,
        modelContext: ModelContext? = nil
    ) async -> CardIcon {
        if let existingIcon, isUserProvidedIcon(existingIcon) {
            return existingIcon
        }

        if let cachedLocationIcon {
            return cachedLocationIcon
        }

        if let modelContext,
           let reused = await CardIconService.shared.findReusableIcon(
               cardName: cardName,
               locationName: locationName,
               websiteUrl: websiteUrl,
               modelContext: modelContext
           ) {
            return reused
        }

        if let registryIcon = await resolveFromBundledRegistry(
            cardName: cardName,
            locationName: locationName
        ) {
            return registryIcon
        }

        if let apiIcon = await resolveFromAPI(
            cardName: cardName,
            locationName: locationName,
            websiteUrl: websiteUrl
        ) {
            return apiIcon
        }

        if let websiteUrl,
           let faviconIcon = await CardIconService.shared.fetchIconFromURL(websiteUrl) {
            return faviconIcon
        }

        let brandName = CardModel.extractBrandName(from: cardName, locationName: locationName)
        if let domainIcon = await BrandLogoService.shared.fetchLogoIcon(for: brandName) {
            return domainIcon
        }

        let iconName = await CardIconService.shared.assignIconForCard(
            name: cardName,
            locationName: locationName
        )
        return CardIcon.sfSymbol(iconName)
    }

    /// Convenience for cards that already store an icon on the model.
    func resolveIcon(for card: CardModel, modelContext: ModelContext? = nil) async -> CardIcon {
        if let stored = card.getIcon(), isPersistableIcon(stored) {
            return stored
        }

        let websiteUrl = card.metadata["websiteUrl"]
        return await resolveIcon(
            cardName: card.name,
            locationName: card.locationName,
            websiteUrl: websiteUrl,
            modelContext: modelContext
        )
    }

    /// Resolve and persist icon on a card model.
    func resolveAndPersist(
        for card: CardModel,
        modelContext: ModelContext? = nil
    ) async {
        let icon = await resolveIcon(for: card, modelContext: modelContext)
        card.setIcon(icon)
    }

    private func isUserProvidedIcon(_ icon: CardIcon) -> Bool {
        switch icon.type {
        case .image, .drawing, .emoji, .text:
            return true
        case .sfSymbol, .automatic:
            return false
        }
    }

    private func isPersistableIcon(_ icon: CardIcon) -> Bool {
        switch icon.type {
        case .image, .drawing, .emoji, .text, .sfSymbol:
            return true
        case .automatic:
            return false
        }
    }

    private func resolveFromBundledRegistry(
        cardName: String,
        locationName: String?
    ) async -> CardIcon? {
        guard let entry = BrandRegistrySnapshot.lookup(
            cardName: cardName,
            locationName: locationName
        ) else {
            return nil
        }

        if let logoUrl = entry.logoUrl, !logoUrl.isEmpty {
            return await BrandLogoService.shared.downloadLogoIcon(
                from: logoUrl,
                cacheKey: entry.name
            )
        }

        if let domain = entry.domain {
            let faviconURL = "https://www.google.com/s2/favicons?domain=\(domain)&sz=128"
            return await BrandLogoService.shared.downloadLogoIcon(
                from: faviconURL,
                cacheKey: entry.name
            )
        }

        return nil
    }

    private func resolveFromAPI(
        cardName: String,
        locationName: String?,
        websiteUrl: String?
    ) async -> CardIcon? {
        guard let response = await BrandResolveClient.shared.resolveBrand(
            name: cardName,
            locationName: locationName,
            websiteUrl: websiteUrl
        ), let logoUrl = response.logoUrl, !logoUrl.isEmpty else {
            return nil
        }

        let cacheKey = response.name.isEmpty
            ? BrandDomainResolver.normalizeBrandName(cardName)
            : response.name

        return await BrandLogoService.shared.downloadLogoIcon(
            from: logoUrl,
            cacheKey: cacheKey
        )
    }
}

/// Lightweight client for the public brand resolve API (no auth required).
actor BrandResolveClient {
    static let shared = BrandResolveClient()

    struct ResolveResponse: Codable {
        let ok: Bool
        let brand: ResolvedBrand

        struct ResolvedBrand: Codable {
            let name: String
            let displayName: String
            let category: String?
            let domain: String
            let logoUrl: String?
            let source: String
            let tier: Int
            let verified: Bool
        }
    }

    private init() {}

    func resolveBrand(
        name: String,
        locationName: String?,
        websiteUrl: String?
    ) async -> ResolveResponse.ResolvedBrand? {
        let baseURLString = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)
            ?? APIClient.defaultBaseURL
        guard var components = URLComponents(string: baseURLString + "/v1/brands/resolve") else {
            return nil
        }

        var queryItems = [URLQueryItem(name: "name", value: name)]
        if let locationName, !locationName.isEmpty {
            queryItems.append(URLQueryItem(name: "locationName", value: locationName))
        }
        if let websiteUrl, !websiteUrl.isEmpty {
            queryItems.append(URLQueryItem(name: "website", value: websiteUrl))
        }
        components.queryItems = queryItems

        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let parsed = try decoder.decode(ResolveResponse.self, from: data)
            return parsed.brand
        } catch {
            return nil
        }
    }
}
