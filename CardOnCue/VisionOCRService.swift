import Foundation
import Vision
import UIKit

/**
 * iOS Vision Framework OCR Service
 *
 * Provides FREE on-device OCR using Apple's Vision framework.
 * No API costs, works offline, and processes images instantly.
 *
 * Use this as a free alternative to OpenAI Vision API for basic card scanning.
 */
class VisionOCRService {

    static let shared = VisionOCRService()

    private init() {}

    struct OCRResult {
        let allText: String
        let cardName: String?
        let memberId: String?
        let barcodeNumber: String?
        let confidence: Float
        let detectedBarcodes: [DetectedBarcode]

        struct DetectedBarcode {
            let type: String
            let value: String?
            let boundingBox: CGRect
        }
    }

    /**
     * Extract text and barcodes from a card image using Vision framework
     *
     * - Parameter image: The card image to analyze
     * - Returns: OCRResult with extracted text and barcode information
     * - Throws: Error if Vision analysis fails
     */
    func analyzeCardImage(_ image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        // Perform text recognition and barcode detection in parallel
        async let textResult = recognizeText(in: cgImage)
        async let barcodeResult = detectBarcodes(in: cgImage)

        let (recognizedText, detectedBarcodes) = try await (textResult, barcodeResult)

        // Parse the recognized text to extract card information
        let parsedInfo = parseCardInformation(from: recognizedText)

        return OCRResult(
            allText: recognizedText.joined(separator: "\n"),
            cardName: parsedInfo.cardName,
            memberId: parsedInfo.memberId,
            barcodeNumber: detectedBarcodes.first?.value ?? parsedInfo.barcodeNumber,
            confidence: parsedInfo.confidence,
            detectedBarcodes: detectedBarcodes.map { barcode in
                OCRResult.DetectedBarcode(
                    type: barcode.type,
                    value: barcode.value,
                    boundingBox: barcode.boundingBox
                )
            }
        )
    }

    /**
     * Recognize text in an image using Vision framework
     */
    private func recognizeText(in image: CGImage) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                continuation.resume(returning: recognizedStrings)
            }

            // Configure for accurate text recognition
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /**
     * Detect barcodes in an image using Vision framework
     */
    private func detectBarcodes(in image: CGImage) async throws -> [(type: String, value: String?, boundingBox: CGRect)] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let barcodes = observations.map { observation in
                    (
                        type: self.barcodeTypeToString(observation.symbology),
                        value: observation.payloadStringValue,
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: barcodes)
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /**
     * Parse card information from recognized text
     */
    private func parseCardInformation(from textLines: [String]) -> (
        cardName: String?,
        memberId: String?,
        barcodeNumber: String?,
        confidence: Float
    ) {
        guard !textLines.isEmpty else {
            return (nil, nil, nil, 0.0)
        }

        // Heuristic: The largest text at the top is likely the card name
        var cardName: String?
        var memberId: String?
        var barcodeNumber: String?

        // Look for card name - check first few lines for valid brand names
        // Skip lines that are clearly not card names (membership levels, person names, etc.)
        // But recognize organization names (libraries, museums, schools, etc.)
        let invalidStandaloneWords = ["membership", "member", "gold", "silver", "bronze", "platinum", "level", "season", "cardholder", "name", "card"]
        let organizationIndicators = ["library", "museum", "school", "university", "college", "hospital", "medical center", "public", "community", "center"]

        // Card type keywords to skip (these are not brand names)
        let cardTypeKeywords = ["pass", "ticket", "entry", "rewards", "loyalty", "fun pass", "gold card", "silver card"]

        for (index, line) in textLines.prefix(7).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip if too short or too long
            guard trimmed.count >= 3 && trimmed.count < 60 else { continue }

            let lowercased = trimmed.lowercased()
            let hasNumbers = trimmed.rangeOfCharacter(from: .decimalDigits) != nil

            // Skip card type keywords (e.g., "FUN PASS")
            let isCardType = cardTypeKeywords.contains { lowercased == $0 || lowercased.contains($0 + " ") || lowercased.contains(" " + $0) }
            if isCardType {
                continue
            }

            // Check if this is an organization name
            let isOrganization = organizationIndicators.contains { lowercased.contains($0) }

            // Skip lines with numbers unless it's an organization
            if hasNumbers && !isOrganization {
                continue
            }

            // Skip standalone invalid words
            let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            let hasOnlyInvalidWords = words.allSatisfy { word in
                invalidStandaloneWords.contains(word.lowercased())
            }
            guard !hasOnlyInvalidWords else { continue }

            // Prioritize organization names (libraries, museums, etc.)
            if isOrganization {
                cardName = trimmed
                break
            }

            // Look for known brand patterns (e.g., "Chuck E. Cheese" - has periods, Title Case)
            let hasProperCase = words.allSatisfy { word in
                word.first?.isUppercase == true || word.count <= 2 // Allow short words like "E."
            }

            // Prefer lines with proper case and at least 2 words (brand names)
            if hasProperCase && words.count >= 2 && cardName == nil {
                cardName = trimmed
            }

            // Fallback: Prefer lines at the top (index 0-4)
            if index < 4 && cardName == nil && hasProperCase {
                cardName = trimmed
            }
        }

        // Look for member ID or barcode number (numeric patterns)
        let numberPattern = try? NSRegularExpression(pattern: "\\d{8,}", options: [])

        for line in textLines {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = numberPattern?.firstMatch(in: line, options: [], range: range) {
                let numberStr = (line as NSString).substring(with: match.range)

                // Assign to memberId or barcodeNumber based on context
                if line.lowercased().contains("member") || line.lowercased().contains("id") {
                    memberId = numberStr
                } else if barcodeNumber == nil {
                    barcodeNumber = numberStr
                }
            }
        }

        // Calculate confidence based on how much we extracted
        var confidence: Float = 0.0
        if cardName != nil { confidence += 0.4 }
        if memberId != nil { confidence += 0.3 }
        if barcodeNumber != nil { confidence += 0.3 }

        return (cardName, memberId, barcodeNumber, confidence)
    }

    /**
     * Convert Vision barcode symbology to string
     */
    private func barcodeTypeToString(_ symbology: VNBarcodeSymbology) -> String {
        switch symbology {
        case .code128:
            return "CODE_128"
        case .code39:
            return "CODE_39"
        case .code93:
            return "CODE_93"
        case .ean8:
            return "EAN_8"
        case .ean13:
            return "EAN_13"
        case .qr:
            return "QR_CODE"
        case .pdf417:
            return "PDF_417"
        case .aztec:
            return "AZTEC"
        case .dataMatrix:
            return "DATA_MATRIX"
        case .upce:
            return "UPC_E"
        case .i2of5:
            return "ITF"
        case .itf14:
            return "ITF_14"
        default:
            return "UNKNOWN"
        }
    }
}

enum OCRError: Error {
    case invalidImage
    case visionRequestFailed
    case noTextFound
}

// MARK: - Usage Example
/**
 * Example: Use VisionOCRService in your card scanning flow

 ```swift
 func scanCardWithVision(_ image: UIImage) async {
     do {
         // FREE on-device OCR using Vision framework
         let result = try await VisionOCRService.shared.analyzeCardImage(image)

         print("Card Name: \(result.cardName ?? "Unknown")")
         print("Member ID: \(result.memberId ?? "None")")
         print("All Text: \(result.allText)")
         print("Confidence: \(result.confidence)")

         // Use detected barcodes
         for barcode in result.detectedBarcodes {
             print("Detected \(barcode.type): \(barcode.value ?? "no value")")
         }

         // Create card with extracted information
         if let cardName = result.cardName,
            let barcodeValue = result.detectedBarcodes.first?.value ?? result.memberId {

             // Call backend to create card
             await createCard(
                 name: cardName,
                 barcodeType: result.detectedBarcodes.first?.type ?? "CODE_128",
                 payload: barcodeValue
             )
         }

     } catch {
         print("Vision OCR failed: \(error)")

         // Fallback to OpenAI Vision API if needed
         await scanCardWithOpenAI(image)
     }
 }

 func scanCardWithOpenAI(_ image: UIImage) async {
     // Convert image to base64
     guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
     let base64Image = imageData.base64EncodedString()

     // Call backend OCR endpoint (uses OpenAI Vision)
     do {
         let result = try await APIClient.shared.post(
             endpoint: "/api/v1/ai/ocr",
             body: ["imageData": "data:image/jpeg;base64,\(base64Image)"]
         )

         // Process OpenAI Vision result
         print("OpenAI OCR result: \(result)")
     } catch {
         print("OpenAI OCR failed: \(error)")
     }
 }
 ```
 */
