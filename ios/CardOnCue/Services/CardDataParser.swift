import Foundation
import CoreLocation
import MapKit

struct ParsedCardData {
    var cardName: String?
    var personName: String?
    var cardType: CardType?
    var suggestedLocations: [LocationSuggestion]
    var rawText: [String]

    init(cardName: String? = nil, personName: String? = nil, cardType: CardType? = nil, suggestedLocations: [LocationSuggestion] = [], rawText: [String] = []) {
        self.cardName = cardName
        self.personName = personName
        self.cardType = cardType
        self.suggestedLocations = suggestedLocations
        self.rawText = rawText
    }
}

struct LocationSuggestion: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D?
    let distance: Double?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LocationSuggestion, rhs: LocationSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

class CardDataParser {
    static let shared = CardDataParser()

    private let nameKeywords = ["member", "name", "cardholder", "belongs to", "issued to"]
    private let libraryKeywords = ["library", "libraries", "public library", "branch"]
    private let membershipKeywords = ["member", "membership", "club", "association"]
    private let loyaltyKeywords = ["rewards", "loyalty", "points", "club card", "perks"]
    private let giftCardKeywords = ["gift card", "gift", "balance", "merchandise"]

    private init() {}

    func parseCard(extractedText: ExtractedCardText, userLocation: CLLocation?) async -> ParsedCardData {
        var parsed = ParsedCardData(rawText: extractedText.allText)

        parsed.cardName = inferCardName(from: extractedText)
        parsed.personName = inferPersonName(from: extractedText)
        parsed.cardType = inferCardType(from: extractedText)

        if let brandName = parsed.cardName {
            parsed.suggestedLocations = await findLocations(
                for: brandName,
                near: userLocation
            )
        }

        return parsed
    }

    private func inferCardName(from text: ExtractedCardText) -> String? {
        if let largestText = text.organizedBySize["large"]?.first, !largestText.isEmpty {
            return cleanCardName(largestText)
        }

        if let topText = text.organizedByPosition["top"]?.first, !topText.isEmpty {
            return cleanCardName(topText)
        }

        return nil
    }

    private func inferPersonName(from text: ExtractedCardText) -> String? {
        for line in text.allText {
            let lowercased = line.lowercased()

            for keyword in nameKeywords {
                if lowercased.contains(keyword) {
                    let components = line.components(separatedBy: ":")
                    if components.count > 1 {
                        let name = components[1].trimmingCharacters(in: .whitespaces)
                        if !name.isEmpty && name.count < 50 {
                            return name
                        }
                    }

                    let withoutKeyword = line.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
                        .trimmingCharacters(in: .whitespaces)
                    if !withoutKeyword.isEmpty && withoutKeyword.count < 50 {
                        return withoutKeyword
                    }
                }
            }
        }

        return nil
    }

    private func inferCardType(from text: ExtractedCardText) -> CardType? {
        let allTextLower = text.allText.map { $0.lowercased() }.joined(separator: " ")

        if libraryKeywords.contains(where: { allTextLower.contains($0) }) {
            return .membership
        }

        if membershipKeywords.contains(where: { allTextLower.contains($0) }) {
            return .membership
        }

        if loyaltyKeywords.contains(where: { allTextLower.contains($0) }) {
            return .loyalty
        }

        if giftCardKeywords.contains(where: { allTextLower.contains($0) }) {
            return .giftCard
        }

        return .membership
    }

    private func cleanCardName(_ name: String) -> String {
        var cleaned = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        if cleaned.count > 40 {
            cleaned = String(cleaned.prefix(40))
        }

        return cleaned
    }

    private func findLocations(for brandName: String, near location: CLLocation?) async -> [LocationSuggestion] {
        guard !brandName.isEmpty else { return [] }

        return await withCheckedContinuation { continuation in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = brandName

            if let location = location {
                request.region = MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 10000,
                    longitudinalMeters: 10000
                )
            }

            let search = MKLocalSearch(request: request)
            search.start { response, error in
                guard let response = response, error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                let suggestions = response.mapItems.prefix(5).compactMap { item -> LocationSuggestion? in
                    guard let name = item.name else { return nil }

                    let address = [
                        item.placemark.thoroughfare,
                        item.placemark.locality,
                        item.placemark.administrativeArea
                    ].compactMap { $0 }.joined(separator: ", ")

                    let distance: Double? = {
                        if let location = location {
                            return item.placemark.location?.distance(from: location)
                        }
                        return nil
                    }()

                    return LocationSuggestion(
                        name: name,
                        address: address,
                        coordinate: item.placemark.coordinate,
                        distance: distance
                    )
                }

                continuation.resume(returning: Array(suggestions))
            }
        }
    }
}
