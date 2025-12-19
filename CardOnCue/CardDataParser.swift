import Foundation
import CoreLocation
import MapKit

struct ParsedCardData {
    var cardName: String?
    var personName: String?
    var personNameConfidence: Float?
    var extractedLocationNames: [String]
    var suggestedLocations: [LocationSuggestion]
    var rawText: [String]

    init(cardName: String? = nil, personName: String? = nil, personNameConfidence: Float? = nil, extractedLocationNames: [String] = [], suggestedLocations: [LocationSuggestion] = [], rawText: [String] = []) {
        self.cardName = cardName
        self.personName = personName
        self.personNameConfidence = personNameConfidence
        self.extractedLocationNames = extractedLocationNames
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

    private let nameKeywords = ["name", "cardholder", "belongs to", "issued to"]

    let commonBusinessChains = [
        "Costco", "Sam's Club", "BJ's", "BJ's Wholesale",
        "LA Fitness", "24 Hour Fitness", "Planet Fitness", "Anytime Fitness", "Gold's Gym",
        "Kroger", "Safeway", "Albertsons", "Publix", "Whole Foods", "Trader Joe's",
        "Target", "Walmart", "Walgreens", "CVS",
        "Starbucks", "Panera", "Chipotle",
        "Best Buy", "Home Depot", "Lowe's",
        "AMC", "Regal", "Cinemark"
    ]

    private let locationKeywords = ["branch", "store", "location", "at"]
    private let companySuffixes = ["LLC", "Inc", "Corp", "Corporation", "Ltd", "Limited", "Co"]
    private let invalidNameWords = ["membership", "member", "gold", "silver", "bronze", "platinum", "level", "tier", "card", "program", "rewards", "points", "club", "account", "status", "ship"]

    private init() {}

    func parseFromVisionOCR(_ ocrResult: VisionOCRService.OCRResult, userLocation: CLLocation?) async -> ParsedCardData {
        let textLines = ocrResult.allText.components(separatedBy: .newlines)
        var parsed = ParsedCardData(
            cardName: ocrResult.cardName,
            rawText: textLines
        )

        let personNameResult = inferPersonNameWithConfidence(from: textLines)
        parsed.personName = personNameResult.name
        parsed.personNameConfidence = personNameResult.confidence

        parsed.extractedLocationNames = extractLocationNames(from: textLines)

        // Detect address first using OCRSegmentDetector
        let segments = OCRSegmentDetector.shared.detectSegments(from: ocrResult, parsedData: parsed)
        let detectedAddress = segments.first { $0.type == .address }?.value

        // Find locations based on card name and extracted location names
        var allLocationQueries = [String]()
        if let brandName = parsed.cardName {
            allLocationQueries.append(brandName)
        }
        allLocationQueries.append(contentsOf: parsed.extractedLocationNames)

        parsed.suggestedLocations = await findLocations(
            for: allLocationQueries,
            near: userLocation,
            detectedAddress: detectedAddress
        )

        return parsed
    }

    /// Extract person name with confidence score using multi-heuristic approach
    private func inferPersonNameWithConfidence(from textLines: [String]) -> (name: String?, confidence: Float) {
        var candidates: [(name: String, confidence: Float)] = []

        // Heuristic 1: Keyword proximity (highest confidence)
        for (index, line) in textLines.enumerated() {
            let lowercased = line.lowercased()

            for keyword in nameKeywords {
                if lowercased.contains(keyword) {
                    // Try extracting after colon
                    let components = line.components(separatedBy: ":")
                    if components.count > 1 {
                        let name = components[1].trimmingCharacters(in: .whitespaces)
                        if isValidPersonName(name) {
                            candidates.append((name: name, confidence: 0.9))
                        }
                    }

                    // Try extracting by removing keyword
                    let withoutKeyword = line.replacingOccurrences(of: keyword, with: "", options: .caseInsensitive)
                        .trimmingCharacters(in: .whitespaces)
                    if isValidPersonName(withoutKeyword) {
                        candidates.append((name: withoutKeyword, confidence: 0.85))
                    }

                    // NEW: Check next line if current line is just the keyword
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedLine.lowercased() == keyword.lowercased() || trimmedLine.count < 15 {
                        // This line might be just a label, check next line
                        if index + 1 < textLines.count {
                            let nextLine = textLines[index + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                            if isValidPersonName(nextLine) {
                                candidates.append((name: nextLine, confidence: 0.95))
                            }
                        }
                    }
                }
            }
        }

        // Heuristic 2: Look for proper case names (but with lower priority than keyword-based)
        for textLine in textLines {
            if isValidPersonName(textLine) && isProperCase(textLine) {
                let score = scorePersonNameCandidate(textLine)
                if score > 0.5 {
                    candidates.append((name: textLine, confidence: score * 0.8)) // Reduced priority
                }
            }
        }

        // Return highest confidence candidate
        if let bestCandidate = candidates.max(by: { $0.confidence < $1.confidence }) {
            return (name: bestCandidate.name, confidence: bestCandidate.confidence)
        }

        return (name: nil, confidence: 0.0)
    }

    /// Check if text is a valid person name
    private func isValidPersonName(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Length check: 2-50 characters (allow single letter last names like "Emma F")
        guard trimmed.count >= 2 && trimmed.count <= 50 else { return false }

        // Word count: 1-5 words typical for names (allow single letter abbreviations)
        let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard words.count >= 1 && words.count <= 5 else { return false }

        // Filter out: numbers
        guard trimmed.rangeOfCharacter(from: .decimalDigits) == nil else { return false }

        // Filter out: company suffixes
        for suffix in companySuffixes {
            if trimmed.hasSuffix(suffix) {
                return false
            }
        }

        // Filter out: invalid name words (membership-related terms)
        let lowercased = trimmed.lowercased()
        for invalidWord in invalidNameWords {
            if lowercased.contains(invalidWord) {
                return false
            }
        }

        return true
    }

    /// Check if text is in proper case (Title Case)
    private func isProperCase(_ text: String) -> Bool {
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !words.isEmpty else { return false }

        for word in words {
            // Skip short words like "de", "von", etc.
            if word.count <= 2 { continue }

            // Check if first letter is uppercase
            guard let firstChar = word.first, firstChar.isUppercase else {
                return false
            }
        }

        return true
    }

    /// Score person name candidate based on multiple factors
    private func scorePersonNameCandidate(_ text: String) -> Float {
        var score: Float = 0.3 // Base score

        // Proper case adds confidence
        if isProperCase(text) {
            score += 0.3
        }

        // Word count: 2-3 words is typical
        let wordCount = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        if wordCount == 2 || wordCount == 3 {
            score += 0.2
        }

        return min(score, 1.0)
    }

    /// Extract location names from card text
    private func extractLocationNames(from textLines: [String]) -> [String] {
        var locations = Set<String>()

        // Search for common business chains
        for line in textLines {
            for chain in commonBusinessChains {
                if line.localizedCaseInsensitiveContains(chain) {
                    locations.insert(chain)
                }
            }
        }

        // Search for location keywords
        for line in textLines {
            let lowercased = line.lowercased()
            for keyword in locationKeywords {
                if lowercased.contains(keyword) {
                    // Extract text around the keyword
                    let components = line.components(separatedBy: CharacterSet.alphanumerics.inverted)
                    let filtered = components.filter { $0.count > 3 }
                    if let locationText = filtered.first {
                        locations.insert(locationText)
                    }
                }
            }
        }

        return Array(locations)
    }

    /// Find locations based on multiple query strings
    private func findLocations(for queries: [String], near location: CLLocation?, detectedAddress: String?) async -> [LocationSuggestion] {
        guard !queries.isEmpty || detectedAddress != nil else { return [] }

        var allSuggestions: [LocationSuggestion] = []

        // PRIORITY 1: Geocode detected address first
        if let address = detectedAddress {
            let addressSuggestions = await geocodeAddress(address, near: location)
            allSuggestions.append(contentsOf: addressSuggestions)
        }

        // PRIORITY 2: Search for each query
        for query in queries {
            let suggestions = await searchLocation(query: query, near: location)
            allSuggestions.append(contentsOf: suggestions)
        }

        // Deduplicate by name and address, sort by distance
        var seen = Set<String>()
        let uniqueSuggestions = allSuggestions.filter { suggestion in
            let key = "\(suggestion.name)-\(suggestion.address)"
            if seen.contains(key) {
                return false
            }
            seen.insert(key)
            return true
        }

        // Sort by distance if available, otherwise keep original order
        let sorted = uniqueSuggestions.sorted { lhs, rhs in
            if let lhsDistance = lhs.distance, let rhsDistance = rhs.distance {
                return lhsDistance < rhsDistance
            }
            return false
        }

        return Array(sorted.prefix(5))
    }

    /// Search for a single location query
    private func searchLocation(query: String, near location: CLLocation?) async -> [LocationSuggestion] {
        guard !query.isEmpty else { return [] }

        return await withCheckedContinuation { continuation in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query

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

                let suggestions = response.mapItems.prefix(3).compactMap { item -> LocationSuggestion? in
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

    /// Geocode a full address string
    private func geocodeAddress(_ address: String, near location: CLLocation?) async -> [LocationSuggestion] {
        return await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()

            geocoder.geocodeAddressString(address) { placemarks, error in
                guard let placemarks = placemarks, error == nil else {
                    continuation.resume(returning: [])
                    return
                }

                let suggestions = placemarks.prefix(3).compactMap { placemark -> LocationSuggestion? in
                    let name = [placemark.name, placemark.thoroughfare].compactMap { $0 }.first ?? "Unknown"

                    let address = [
                        placemark.thoroughfare,
                        placemark.locality,
                        placemark.administrativeArea,
                        placemark.postalCode
                    ].compactMap { $0 }.joined(separator: ", ")

                    let distance: Double? = {
                        if let location = location, let placemarkLocation = placemark.location {
                            return placemarkLocation.distance(from: location)
                        }
                        return nil
                    }()

                    return LocationSuggestion(
                        name: name,
                        address: address,
                        coordinate: placemark.location?.coordinate,
                        distance: distance
                    )
                }

                continuation.resume(returning: Array(suggestions))
            }
        }
    }
}
