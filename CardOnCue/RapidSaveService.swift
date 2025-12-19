import Foundation

/// Service responsible for evaluating whether a scanned card should be auto-saved
/// based on OCR confidence, context, and smart name generation
class RapidSaveService {

    // MARK: - Singleton

    static let shared = RapidSaveService()

    private init() {}

    // MARK: - Save Decision

    /// Result of evaluating whether to auto-save a card
    struct SaveDecision {
        let shouldAutoSave: Bool
        let confidence: Float
        let suggestedName: String
        let reason: String
    }

    // MARK: - Evaluation Method

    /// Evaluate whether a scanned card should be auto-saved based on confidence and context
    func evaluateSave(
        ocrResult: VisionOCRService.OCRResult,
        parsedData: ParsedCardData,
        batchContext: BatchLocationContext?,
        threshold: Float = 0.85
    ) async -> SaveDecision {

        // Calculate composite confidence score
        let compositeConfidence = calculateCompositeConfidence(
            ocrConfidence: ocrResult.confidence,
            parsedData: parsedData,
            batchContext: batchContext
        )

        // Determine if auto-save is appropriate
        let shouldAutoSave = compositeConfidence >= threshold

        // Generate smart name
        let suggestedName = generateSmartName(
            parsedData: parsedData,
            batchContext: batchContext,
            confidence: compositeConfidence
        )

        // Determine reason
        let reason: String
        if shouldAutoSave {
            reason = "High confidence OCR (\(Int(compositeConfidence * 100))%)"
        } else {
            reason = "Manual review needed (confidence: \(Int(compositeConfidence * 100))%)"
        }

        return SaveDecision(
            shouldAutoSave: shouldAutoSave,
            confidence: compositeConfidence,
            suggestedName: suggestedName,
            reason: reason
        )
    }

    // MARK: - Confidence Calculation

    /// Calculate composite confidence score from multiple factors
    private func calculateCompositeConfidence(
        ocrConfidence: Float,
        parsedData: ParsedCardData,
        batchContext: BatchLocationContext?
    ) -> Float {

        var score: Float = 0.0

        // Base OCR confidence (50% weight)
        score += ocrConfidence * 0.5

        // Boost for person name detection (20% weight)
        if let personConfidence = parsedData.personNameConfidence {
            score += personConfidence * 0.2
        }

        // Boost for location context
        if batchContext != nil {
            // Batch context provides known location (15% boost)
            score += 0.15
        } else if !parsedData.suggestedLocations.isEmpty {
            // Location detected from OCR (10% boost)
            score += 0.10
        }

        // Boost for known brand recognition (5% weight)
        if let cardName = parsedData.cardName,
           CardDataParser.shared.isKnownBusinessChain(cardName) {
            score += 0.05
        }

        // Cap at 1.0
        return min(score, 1.0)
    }

    // MARK: - Smart Name Generation

    /// Generate a smart card name based on available data and context
    private func generateSmartName(
        parsedData: ParsedCardData,
        batchContext: BatchLocationContext?,
        confidence: Float
    ) -> String {

        // Priority 1: Batch context + person name
        // Example: "Luke's Chuck E. Cheese"
        if let location = batchContext,
           let person = parsedData.personName {
            let firstName = extractFirstName(from: person)
            return "\(firstName)'s \(location.locationName)"
        }

        // Priority 2: Brand + person name
        // Example: "Emma's Costco"
        if let brand = parsedData.cardName,
           let person = parsedData.personName {
            let firstName = extractFirstName(from: person)
            return "\(firstName)'s \(brand)"
        }

        // Priority 3: Batch location only
        // Example: "Chuck E. Cheese"
        if let location = batchContext {
            return location.locationName
        }

        // Priority 4: Location from OCR
        // Example: "Louisville Public Library"
        if let location = parsedData.suggestedLocations.first {
            return location.name
        }

        // Priority 5: Brand only
        // Example: "Costco"
        if let brand = parsedData.cardName {
            return brand
        }

        // Priority 6: Person name + "Card"
        // Example: "John Smith's Card"
        if let person = parsedData.personName {
            return "\(person)'s Card"
        }

        // Fallback: Generic name with date if low confidence
        if confidence < 0.70 {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "Card \(formatter.string(from: Date()))"
        }

        return "New Card"
    }

    // MARK: - Helper Methods

    /// Extract first name from full name
    private func extractFirstName(from fullName: String) -> String {
        let components = fullName.components(separatedBy: " ")
        return components.first ?? fullName
    }
}

// MARK: - CardDataParser Extension

extension CardDataParser {
    /// Check if a business name is in the known chains list
    func isKnownBusinessChain(_ name: String) -> Bool {
        return commonBusinessChains.contains { chain in
            name.lowercased().contains(chain.lowercased())
        }
    }
}
