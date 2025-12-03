import Foundation
import Vision
import UIKit
import CoreLocation

struct ExtractedCardText {
    let allText: [String]
    let organizedBySize: [String: [String]]
    let organizedByPosition: [String: [String]]
}

class CardOCRService {
    static let shared = CardOCRService()

    private init() {}

    func extractText(from image: UIImage) async -> ExtractedCardText? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                var allText: [String] = []
                var textBySize: [String: [String]] = [
                    "large": [],
                    "medium": [],
                    "small": []
                ]
                var textByPosition: [String: [String]] = [
                    "top": [],
                    "middle": [],
                    "bottom": []
                ]

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let text = candidate.string
                    allText.append(text)

                    let boundingBox = observation.boundingBox
                    let height = boundingBox.height
                    let y = boundingBox.origin.y

                    if height > 0.1 {
                        textBySize["large"]?.append(text)
                    } else if height > 0.05 {
                        textBySize["medium"]?.append(text)
                    } else {
                        textBySize["small"]?.append(text)
                    }

                    if y > 0.66 {
                        textByPosition["top"]?.append(text)
                    } else if y > 0.33 {
                        textByPosition["middle"]?.append(text)
                    } else {
                        textByPosition["bottom"]?.append(text)
                    }
                }

                let extracted = ExtractedCardText(
                    allText: allText,
                    organizedBySize: textBySize,
                    organizedByPosition: textByPosition
                )

                continuation.resume(returning: extracted)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                print("OCR error: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
}
