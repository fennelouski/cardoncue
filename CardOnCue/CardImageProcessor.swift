import Foundation
import Vision
import CoreImage
import UIKit

/// Result of card image processing
struct ProcessedCardImage {
    let original: UIImage
    let processed: UIImage?
    let confidence: Float
    let processingMetadata: ProcessingMetadata?
    
    /// Whether processing was successful
    var isProcessed: Bool {
        processed != nil && confidence > 0.5
    }
}

/// Metadata about the image processing operation
struct ProcessingMetadata: Codable, Sendable {
    let algorithmVersion: String
    let detectionConfidence: Float
    let cornersDetected: [[Double]]
    let processingTimeMs: Int
    let enhancementsApplied: [String]
    let originalDimensions: ImageDimensions
    let processedDimensions: ImageDimensions?
}

struct ImageDimensions: Codable, Sendable {
    let width: Int
    let height: Int
}

/// Errors that can occur during card image processing
enum CardProcessingError: LocalizedError {
    case noCardDetected
    case invalidImage
    case processingFailed(String)
    case lowConfidence(Float)
    
    var errorDescription: String? {
        switch self {
        case .noCardDetected:
            return "Could not detect a card in the image. Please ensure the card is clearly visible."
        case .invalidImage:
            return "Invalid image format"
        case .processingFailed(let reason):
            return "Image processing failed: \(reason)"
        case .lowConfidence(let confidence):
            return "Card detection confidence too low (\(Int(confidence * 100))%). The card may not be clearly visible."
        }
    }
}

/// Service for automatically cropping and straightening card images
class CardImageProcessor {
    static let shared = CardImageProcessor()
    
    private let algorithmVersion = "1.0"
    private let context: CIContext
    
    private init() {
        // Use hardware-accelerated rendering when available
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .workingColorSpace: CGColorSpaceCreateDeviceRGB()
        ]
        self.context = CIContext(options: options)
    }
    
    // MARK: - Main Processing Pipeline
    
    /// Process a card image: detect boundaries, apply perspective correction, and crop
    /// - Parameter original: The original card image
    /// - Returns: ProcessedCardImage with both original and processed versions
    func processCardImage(original: UIImage) async throws -> ProcessedCardImage {
        let startTime = Date()
        
        guard let ciImage = CIImage(image: original) else {
            throw CardProcessingError.invalidImage
        }
        
        let originalDimensions = ImageDimensions(
            width: Int(original.size.width),
            height: Int(original.size.height)
        )
        
        // Step 1: Detect card rectangle
        let rectangle: VNRectangleObservation
        do {
            rectangle = try await detectCard(in: ciImage)
        } catch {
            // If detection fails, return original with low confidence
            return ProcessedCardImage(
                original: original,
                processed: nil,
                confidence: 0.0,
                processingMetadata: ProcessingMetadata(
                    algorithmVersion: algorithmVersion,
                    detectionConfidence: 0.0,
                    cornersDetected: [],
                    processingTimeMs: Int(Date().timeIntervalSince(startTime) * 1000),
                    enhancementsApplied: [],
                    originalDimensions: originalDimensions,
                    processedDimensions: nil
                )
            )
        }
        
        // Check confidence threshold
        guard rectangle.confidence >= 0.5 else {
            throw CardProcessingError.lowConfidence(rectangle.confidence)
        }
        
        // Step 2: Apply perspective correction
        let straightened = straightenCard(image: ciImage, rectangle: rectangle)
        
        // Step 3: Optional enhancements
        let enhanced = enhanceCard(image: straightened)
        
        // Step 4: Convert back to UIImage
        guard let cgImage = context.createCGImage(enhanced, from: enhanced.extent) else {
            throw CardProcessingError.processingFailed("Failed to create CGImage from processed image")
        }
        
        let processedImage = UIImage(cgImage: cgImage)
        let processingTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
        
        // Extract corner coordinates
        let corners = [
            [Double(rectangle.topLeft.x), Double(rectangle.topLeft.y)],
            [Double(rectangle.topRight.x), Double(rectangle.topRight.y)],
            [Double(rectangle.bottomRight.x), Double(rectangle.bottomRight.y)],
            [Double(rectangle.bottomLeft.x), Double(rectangle.bottomLeft.y)]
        ]
        
        let processedDimensions = ImageDimensions(
            width: Int(processedImage.size.width),
            height: Int(processedImage.size.height)
        )
        
        let metadata = ProcessingMetadata(
            algorithmVersion: algorithmVersion,
            detectionConfidence: rectangle.confidence,
            cornersDetected: corners,
            processingTimeMs: processingTimeMs,
            enhancementsApplied: ["perspective_correction", "auto_contrast"],
            originalDimensions: originalDimensions,
            processedDimensions: processedDimensions
        )
        
        return ProcessedCardImage(
            original: original,
            processed: processedImage,
            confidence: rectangle.confidence,
            processingMetadata: metadata
        )
    }
    
    // MARK: - Card Detection
    
    /// Detect card rectangle in image using Vision Framework
    private func detectCard(in image: CIImage) async throws -> VNRectangleObservation {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRectangleObservation],
                      let observation = observations.first else {
                    continuation.resume(throwing: CardProcessingError.noCardDetected)
                    return
                }
                
                continuation.resume(returning: observation)
            }
            
            // Configure for card detection
            // Credit cards are approximately 1.586:1 aspect ratio (85.6mm × 53.98mm)
            request.minimumAspectRatio = 0.5  // Allow for various card types
            request.maximumAspectRatio = 2.0
            request.minimumSize = 0.2  // Card should be at least 20% of image
            request.quadratureTolerance = 15  // Degrees of corner angle tolerance
            request.minimumConfidence = 0.5  // Minimum confidence threshold
            
            let handler = VNImageRequestHandler(ciImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: CardProcessingError.processingFailed(error.localizedDescription))
            }
        }
    }
    
    // MARK: - Perspective Correction
    
    /// Apply perspective correction to straighten the card
    private func straightenCard(image: CIImage, rectangle: VNRectangleObservation) -> CIImage {
        guard let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection") else {
            return image
        }
        
        // Convert Vision coordinates (normalized 0-1, origin bottom-left)
        // to Core Image coordinates (pixels, origin top-left)
        let imageSize = image.extent.size
        
        let topLeft = CGPoint(
            x: rectangle.topLeft.x * imageSize.width,
            y: (1.0 - rectangle.topLeft.y) * imageSize.height
        )
        let topRight = CGPoint(
            x: rectangle.topRight.x * imageSize.width,
            y: (1.0 - rectangle.topRight.y) * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: rectangle.bottomLeft.x * imageSize.width,
            y: (1.0 - rectangle.bottomLeft.y) * imageSize.height
        )
        let bottomRight = CGPoint(
            x: rectangle.bottomRight.x * imageSize.width,
            y: (1.0 - rectangle.bottomRight.y) * imageSize.height
        )
        
        // Calculate target dimensions based on detected card size
        let topWidth = distance(topLeft, topRight)
        let bottomWidth = distance(bottomLeft, bottomRight)
        let leftHeight = distance(topLeft, bottomLeft)
        let rightHeight = distance(topRight, bottomRight)
        
        let avgWidth = (topWidth + bottomWidth) / 2
        let avgHeight = (leftHeight + rightHeight) / 2
        let aspectRatio = avgWidth / avgHeight
        
        // Scale to reasonable size (max 1200px on longest side)
        let maxDimension: CGFloat = 1200
        let targetWidth: CGFloat
        let targetHeight: CGFloat
        
        if avgWidth > avgHeight {
            targetWidth = maxDimension
            targetHeight = maxDimension / aspectRatio
        } else {
            targetWidth = maxDimension * aspectRatio
            targetHeight = maxDimension
        }
        
        perspectiveCorrection.setValue(image, forKey: kCIInputImageKey)
        
        // Set source points (detected card corners in image coordinates)
        // CIPerspectiveCorrection automatically creates a rectangular output
        perspectiveCorrection.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        perspectiveCorrection.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        perspectiveCorrection.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")
        perspectiveCorrection.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        
        guard let output = perspectiveCorrection.outputImage else {
            return image
        }
        
        // Calculate the actual output size from the filter
        // The output extent might be larger than our target, so we'll scale and crop
        let outputExtent = output.extent
        
        // Scale to fit target dimensions while maintaining aspect ratio
        let scaleX = targetWidth / outputExtent.width
        let scaleY = targetHeight / outputExtent.height
        let scale = min(scaleX, scaleY)
        
        // Apply scale transform
        guard let scaleFilter = CIFilter(name: "CIAffineTransform") else {
            return output
        }
        
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        scaleFilter.setValue(output, forKey: kCIInputImageKey)
        scaleFilter.setValue(NSValue(cgAffineTransform: transform), forKey: kCIInputTransformKey)
        
        guard let scaledOutput = scaleFilter.outputImage else {
            return output
        }
        
        // Crop to target dimensions (centered)
        let cropRect = CGRect(
            x: (scaledOutput.extent.width - targetWidth) / 2,
            y: (scaledOutput.extent.height - targetHeight) / 2,
            width: targetWidth,
            height: targetHeight
        )
        
        return scaledOutput.cropped(to: cropRect)
    }
    
    /// Calculate distance between two points
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // MARK: - Image Enhancement
    
    /// Apply optional enhancements to improve image quality
    private func enhanceCard(image: CIImage) -> CIImage {
        // Use Core Image's auto-adjustment filters
        let filters = image.autoAdjustmentFilters(options: [
            .enhance: true,
            .redEye: false
        ])
        
        var enhanced = image
        
        for filter in filters {
            filter.setValue(enhanced, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                enhanced = output
            }
        }
        
        return enhanced
    }
}

