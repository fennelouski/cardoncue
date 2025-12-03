import Foundation
import UIKit
import CryptoKit

struct CardSignature {
    let imageHash: String
    let textSignature: String?
}

struct CardTemplate: Codable {
    let id: String
    let imageHash: String
    let textSignature: String?
    let cardName: String
    let cardType: String?
    let locationName: String?
    let locationAddress: String?
    let locationLat: Double?
    let locationLng: Double?
    let confidenceScore: Double
    let usageCount: Int
    let verified: Bool
}

class CardSignatureService {
    static let shared = CardSignatureService()

    private let baseURL = "https://www.cardoncue.com/api/v1"

    private init() {}

    func computeSignature(image: UIImage, extractedText: ExtractedCardText) -> CardSignature {
        let imageHash = computePerceptualHash(from: image)
        let textSignature = computeTextSignature(from: extractedText)

        return CardSignature(
            imageHash: imageHash,
            textSignature: textSignature
        )
    }

    func findMatchingTemplates(signature: CardSignature) async -> [CardTemplate] {
        guard let url = URL(string: "\(baseURL)/card-templates/match") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "imageHash": signature.imageHash,
            "textSignature": signature.textSignature as Any,
            "limit": 5
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return []
        }

        request.httpBody = jsonData

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(MatchResponse.self, from: data)
            return response.matches
        } catch {
            print("Error fetching card templates: \(error)")
            return []
        }
    }

    func submitTemplate(
        signature: CardSignature,
        cardName: String,
        cardType: String?,
        locationName: String?,
        locationAddress: String?,
        locationLat: Double?,
        locationLng: Double?
    ) async {
        guard let url = URL(string: "\(baseURL)/card-templates") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "imageHash": signature.imageHash,
            "textSignature": signature.textSignature as Any,
            "cardName": cardName,
            "cardType": cardType as Any,
            "locationName": locationName as Any,
            "locationAddress": locationAddress as Any,
            "locationLat": locationLat as Any,
            "locationLng": locationLng as Any,
            "confidenceScore": 0.7
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return
        }

        request.httpBody = jsonData

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            print("Error submitting card template: \(error)")
        }
    }

    private func computePerceptualHash(from image: UIImage) -> String {
        // Resize image to 8x8 for perceptual hashing
        guard let resized = image.resized(to: CGSize(width: 8, height: 8)),
              let cgImage = resized.cgImage else {
            return ""
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return ""
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Calculate average brightness
        var total = 0
        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let r = Int(pixelData[i])
            let g = Int(pixelData[i + 1])
            let b = Int(pixelData[i + 2])
            total += (r + g + b) / 3
        }

        let average = total / (width * height)

        // Create hash based on comparison to average
        var hash = ""
        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let r = Int(pixelData[i])
            let g = Int(pixelData[i + 1])
            let b = Int(pixelData[i + 2])
            let brightness = (r + g + b) / 3
            hash += brightness > average ? "1" : "0"
        }

        // Convert binary string to hex
        return binaryToHex(hash)
    }

    private func computeTextSignature(from extractedText: ExtractedCardText) -> String? {
        // Normalize and hash the most prominent text elements
        var significantText = extractedText.organizedBySize["large"] ?? []
        significantText += extractedText.organizedByPosition["top"] ?? []

        if significantText.isEmpty {
            return nil
        }

        // Normalize text: lowercase, remove special characters, sort
        let normalized = significantText
            .map { text in
                text.lowercased()
                    .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
            }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: "_")

        if normalized.isEmpty {
            return nil
        }

        // Compute SHA256 hash and take first 16 characters
        let data = Data(normalized.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    private func binaryToHex(_ binary: String) -> String {
        var hex = ""
        let chars = Array(binary)

        for i in stride(from: 0, to: chars.count, by: 4) {
            let chunk = String(chars[i..<min(i+4, chars.count)])
            if let value = Int(chunk, radix: 2) {
                hex += String(format: "%X", value)
            }
        }

        return hex
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

struct MatchResponse: Codable {
    let matches: [CardTemplate]
    let count: Int
}
