import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device Apple Intelligence pass over a card's OCR text. Reads messy scans far
/// better than the keyword heuristics in `CardDataParser`, which it refines rather
/// than replaces: any field the model leaves empty keeps the heuristic value.
/// Runs entirely on device; nothing leaves the phone.
enum CardIntelligence {
    static let userDefaultsKey = "useAppleIntelligence"

    enum Status { case available, notEnabled, notReady, unsupported }

    static var status: Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return .available
            case .unavailable(.appleIntelligenceNotEnabled): return .notEnabled
            case .unavailable(.modelNotReady): return .notReady
            default: return .unsupported
            }
        }
        #endif
        return .unsupported
    }

    /// User toggle (Settings), on by default.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: userDefaultsKey) as? Bool ?? true
    }

    static var isActive: Bool { isEnabled && status == .available }

    /// Fills in fields of `parsed` from the model. No-op when unavailable or on error.
    static func refine(_ parsed: inout ParsedCardData, ocrText: String) async {
        #if canImport(FoundationModels)
        guard isActive, #available(iOS 26.0, *) else { return }
        let text = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let session = LanguageModelSession(instructions: """
                You read OCR text from a photo of a membership, loyalty, library, gym or gift card.
                Extract only what is actually printed on the card. Leave a field empty when unsure.
                The OCR may contain typos; correct obvious misspellings of well-known brand names.
                """)
            let result = try await session.respond(
                to: "OCR text, one line per line on the card:\n\(text.prefix(2000))",
                generating: CardExtraction.self
            ).content
            apply(result.brandName, result.cardholderName, result.membershipLevel, result.expirationDate, to: &parsed)
        } catch {
            print("⚠️ Apple Intelligence card extraction failed: \(error)")
        }
        #endif
    }

    /// Merge rule, split out so it is testable without the model.
    static func apply(_ brand: String?, _ holder: String?, _ level: String?, _ expiry: String?, to parsed: inout ParsedCardData) {
        func clean(_ s: String?) -> String? {
            guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
            return t
        }
        if let brand = clean(brand) { parsed.cardName = brand }
        if let holder = clean(holder) {
            parsed.personName = holder
            parsed.personNameConfidence = max(parsed.personNameConfidence ?? 0, 0.9)
        }
        if let level = clean(level) { parsed.membershipLevel = level }
        if let expiry = clean(expiry) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"
            if let date = f.date(from: expiry) { parsed.expirationDate = date }
        }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct CardExtraction {
    @Guide(description: "The business or organization that issued the card, e.g. \"Costco\" or \"Seattle Public Library\". Not the program name or tier.")
    var brandName: String?
    @Guide(description: "The cardholder's personal name, if printed. Never a business name.")
    var cardholderName: String?
    @Guide(description: "Membership tier or card type, e.g. \"Gold\", \"Executive\", \"Student\".")
    var membershipLevel: String?
    @Guide(description: "Expiration date as yyyy-MM-dd, only if an expiry or valid-through date is printed.")
    var expirationDate: String?
}
#endif
