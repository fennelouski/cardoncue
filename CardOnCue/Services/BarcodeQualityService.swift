import Foundation
import UIKit
import Vision
import CoreImage

class BarcodeQualityService {
    static let shared = BarcodeQualityService()

    private init() {}

    // MARK: - Automatic Barcode Detection and Extraction

    /// Detects all barcodes in an image and extracts their data
    /// Returns an array of detected barcodes sorted by confidence (highest first)
    func detectBarcodes(in image: UIImage) async -> [DetectedBarcodeData] {
        guard let cgImage = image.cgImage else { return [] }

        let request = VNDetectBarcodesRequest()
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try requestHandler.perform([request])

            guard let results = request.results, !results.isEmpty else {
                return []
            }

            var detectedBarcodes: [DetectedBarcodeData] = []

            for observation in results {
                if let barcodeType = convertSymbology(observation.symbology),
                   let payload = observation.payloadStringValue {
                    let detected = DetectedBarcodeData(
                        barcodeType: barcodeType,
                        payload: payload,
                        confidence: Double(observation.confidence),
                        detectedSymbology: observation.symbology.rawValue,
                        boundingBox: observation.boundingBox
                    )
                    detectedBarcodes.append(detected)
                }
            }

            // Sort by confidence (highest first)
            return detectedBarcodes.sorted { $0.confidence > $1.confidence }
        } catch {
            print("Barcode detection error: \(error)")
            return []
        }
    }

    /// Detects the best (highest confidence) barcode in an image
    func detectBestBarcode(in image: UIImage) async -> DetectedBarcodeData? {
        let barcodes = await detectBarcodes(in: image)
        return barcodes.first
    }

    // MARK: - Quality Evaluation

    func evaluateImage(_ image: UIImage, expectedBarcodeType: BarcodeType) async -> BarcodeQualityMetrics {
        let readabilityScore = await evaluateReadability(image, expectedType: expectedBarcodeType)
        let sharpnessScore = evaluateSharpness(image)
        let contrastScore = evaluateContrast(image)

        return BarcodeQualityMetrics(
            readabilityScore: readabilityScore,
            imageSharpness: sharpnessScore,
            contrastScore: contrastScore
        )
    }

    private func evaluateReadability(_ image: UIImage, expectedType: BarcodeType) async -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }

        let request = VNDetectBarcodesRequest()
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try requestHandler.perform([request])

            guard let results = request.results, !results.isEmpty else {
                return 0.0
            }

            var bestScore = 0.0
            for observation in results {
                if matchesBarcodeType(observation.symbology, expectedType: expectedType) {
                    bestScore = max(bestScore, Double(observation.confidence))
                }
            }

            return bestScore
        } catch {
            print("Barcode detection error: \(error)")
            return 0.0
        }
    }

    // MARK: - Symbology Conversion

    /// Converts Vision framework symbology to our BarcodeType enum
    private func convertSymbology(_ symbology: VNBarcodeSymbology) -> BarcodeType? {
        switch symbology {
        case .qr:
            return .qr
        case .code128:
            return .code128
        case .pdf417:
            return .pdf417
        case .aztec:
            return .aztec
        case .ean13:
            return .ean13
        case .upce:
            return .upcA
        case .code39:
            return .code39
        case .itf14:
            return .itf
        default:
            // Unsupported barcode type
            return nil
        }
    }

    private func matchesBarcodeType(_ symbology: VNBarcodeSymbology, expectedType: BarcodeType) -> Bool {
        guard let convertedType = convertSymbology(symbology) else {
            return false
        }
        return convertedType == expectedType
    }

    private func evaluateSharpness(_ image: UIImage) -> Double {
        guard let ciImage = CIImage(image: image) else { return 0.0 }

        let filter = CIFilter(name: "CIEdges")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.0, forKey: kCIInputIntensityKey)

        guard let outputImage = filter?.outputImage else { return 0.0 }

        let context = CIContext()
        let extent = outputImage.extent

        let inputExtent = CIVector(
            x: extent.origin.x,
            y: extent.origin.y,
            z: extent.size.width,
            w: extent.size.height
        )

        guard let averageFilter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: outputImage,
            kCIInputExtentKey: inputExtent
        ]),
        let outputImage = averageFilter.outputImage else {
            return 0.0
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        let averageEdgeStrength = Double(bitmap[0]) / 255.0
        return min(averageEdgeStrength * 2.0, 1.0)
    }

    private func evaluateContrast(_ image: UIImage) -> Double {
        guard let ciImage = CIImage(image: image) else { return 0.0 }

        let extent = ciImage.extent
        let inputExtent = CIVector(
            x: extent.origin.x,
            y: extent.origin.y,
            z: extent.size.width,
            w: extent.size.height
        )

        guard let minFilter = CIFilter(name: "CIAreaMinimum", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: inputExtent
        ]),
        let maxFilter = CIFilter(name: "CIAreaMaximum", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: inputExtent
        ]) else {
            return 0.0
        }

        let context = CIContext()

        var minBitmap = [UInt8](repeating: 0, count: 4)
        var maxBitmap = [UInt8](repeating: 0, count: 4)

        if let minOutput = minFilter.outputImage {
            context.render(
                minOutput,
                toBitmap: &minBitmap,
                rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: nil
            )
        }

        if let maxOutput = maxFilter.outputImage {
            context.render(
                maxOutput,
                toBitmap: &maxBitmap,
                rowBytes: 4,
                bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                format: .RGBA8,
                colorSpace: nil
            )
        }

        let minLuminance = Double(minBitmap[0])
        let maxLuminance = Double(maxBitmap[0])

        if maxLuminance == 0 { return 0.0 }

        let contrastRatio = (maxLuminance - minLuminance) / maxLuminance

        return min(contrastRatio * 1.5, 1.0)
    }

    func suggestImprovements(for metrics: BarcodeQualityMetrics) -> [String] {
        var suggestions: [String] = []

        if metrics.readabilityScore < 0.5 {
            suggestions.append("Barcode not detected. Try better lighting or a clearer photo.")
        } else if metrics.readabilityScore < 0.7 {
            suggestions.append("Barcode detection is weak. Consider retaking the photo.")
        }

        if metrics.imageSharpness < 0.4 {
            suggestions.append("Image is blurry. Hold the device steady and ensure good focus.")
        } else if metrics.imageSharpness < 0.6 {
            suggestions.append("Image could be sharper. Try tapping to focus before capturing.")
        }

        if metrics.contrastScore < 0.4 {
            suggestions.append("Low contrast. Improve lighting or use the contrast adjustment.")
        } else if metrics.contrastScore < 0.6 {
            suggestions.append("Contrast could be better. Try adjusting brightness or lighting.")
        }

        if suggestions.isEmpty {
            suggestions.append("Quality looks good!")
        }

        return suggestions
    }

    func shouldRecommendDigitalBarcode(metrics: BarcodeQualityMetrics) -> Bool {
        // Digital barcodes are almost always better than scanned ones.
        // Only recommend scanned if it's exceptionally high quality (90%+) AND
        // has very high readability (95%+). This ensures lock screen scanning works reliably.
        return metrics.overallScore < 0.90 || metrics.readabilityScore < 0.95
    }
}
