import Foundation
import CoreGraphics

enum BarcodeRepresentation: String, Codable {
    case digital
    case scannedImage
    case automatic
}

struct ImageEditingMetadata: Codable, Hashable {
    var cropRect: CGRect?
    var rotationAngle: Double
    var contrastAdjustment: Double
    var brightnessAdjustment: Double
    var perspectiveCorrectionPoints: [CGPoint]?

    init(
        cropRect: CGRect? = nil,
        rotationAngle: Double = 0.0,
        contrastAdjustment: Double = 1.0,
        brightnessAdjustment: Double = 0.0,
        perspectiveCorrectionPoints: [CGPoint]? = nil
    ) {
        self.cropRect = cropRect
        self.rotationAngle = rotationAngle
        self.contrastAdjustment = contrastAdjustment
        self.brightnessAdjustment = brightnessAdjustment
        self.perspectiveCorrectionPoints = perspectiveCorrectionPoints
    }
}

struct BarcodeImageData: Codable, Hashable {
    let localFilePath: String
    var editingMetadata: ImageEditingMetadata?
    var qualityScore: Double?
    let capturedAt: Date
    var barcodeBoundingBox: CGRect?  // For automatic cropping to barcode area

    init(
        localFilePath: String,
        editingMetadata: ImageEditingMetadata? = nil,
        qualityScore: Double? = nil,
        capturedAt: Date = Date(),
        barcodeBoundingBox: CGRect? = nil
    ) {
        self.localFilePath = localFilePath
        self.editingMetadata = editingMetadata
        self.qualityScore = qualityScore
        self.capturedAt = capturedAt
        self.barcodeBoundingBox = barcodeBoundingBox
    }

    var hasBeenEdited: Bool {
        guard let metadata = editingMetadata else { return false }
        return metadata.cropRect != nil ||
               metadata.rotationAngle != 0.0 ||
               metadata.contrastAdjustment != 1.0 ||
               metadata.brightnessAdjustment != 0.0 ||
               metadata.perspectiveCorrectionPoints != nil
    }
}

struct CardFrontImage: Codable, Hashable {
    let localFilePath: String
    var editingMetadata: ImageEditingMetadata?
    let capturedAt: Date

    init(
        localFilePath: String,
        editingMetadata: ImageEditingMetadata? = nil,
        capturedAt: Date = Date()
    ) {
        self.localFilePath = localFilePath
        self.editingMetadata = editingMetadata
        self.capturedAt = capturedAt
    }
}

struct BarcodeQualityMetrics: Codable, Hashable {
    var readabilityScore: Double
    var imageSharpness: Double
    var contrastScore: Double
    var overallScore: Double

    init(
        readabilityScore: Double = 0.0,
        imageSharpness: Double = 0.0,
        contrastScore: Double = 0.0
    ) {
        self.readabilityScore = readabilityScore
        self.imageSharpness = imageSharpness
        self.contrastScore = contrastScore
        self.overallScore = (readabilityScore + imageSharpness + contrastScore) / 3.0
    }
}

struct DetectedBarcodeData: Hashable {
    let barcodeType: BarcodeType
    let payload: String
    let confidence: Double
    let detectedSymbology: String
    let boundingBox: CGRect  // Normalized coordinates (0-1) of barcode in image

    init(barcodeType: BarcodeType, payload: String, confidence: Double, detectedSymbology: String, boundingBox: CGRect) {
        self.barcodeType = barcodeType
        self.payload = payload
        self.confidence = confidence
        self.detectedSymbology = detectedSymbology
        self.boundingBox = boundingBox
    }
}
