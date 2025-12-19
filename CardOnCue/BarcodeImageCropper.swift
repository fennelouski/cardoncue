import Foundation
import UIKit
import CoreGraphics

/// Service for cropping barcode regions from card images and caching to disk
class BarcodeImageCropper {
    private let imageStorageService: CardImageStorageService

    init(imageStorageService: CardImageStorageService = .shared) {
        self.imageStorageService = imageStorageService
    }

    /// Crops image to barcode region and caches to disk
    /// Returns the file path (as String) of the cropped image
    func cropAndCacheBarcodeImage(for card: CardModel) async -> String? {
        // Check if already cached
        if let cachedURL = card.croppedBarcodeImageURL,
           FileManager.default.fileExists(atPath: cachedURL) {
            return cachedURL
        }

        // Validate we have required data
        guard let boundingBox = card.barcodeBoundingBox,
              let imageURLString = card.displayImageURL,
              let imageURL = URL(string: imageURLString) else {
            return nil
        }

        // Load the source image
        guard let sourceImage = imageStorageService.loadImage(from: imageURL) else {
            return nil
        }

        // Crop the image to barcode region
        guard let croppedImage = cropImage(sourceImage, boundingBox: boundingBox) else {
            return nil
        }

        // Save to disk
        do {
            let fileURL = try saveCroppedBarcodeImage(croppedImage, cardId: card.id)
            return fileURL.path
        } catch {
            print("Error saving cropped barcode image: \(error)")
            return nil
        }
    }

    /// Loads cached cropped barcode image if available
    func loadCroppedBarcodeImage(from urlString: String) -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        return imageStorageService.loadImage(from: url)
    }

    /// Deletes cached cropped barcode image
    func deleteCroppedBarcodeImage(at urlString: String) {
        guard let url = URL(string: urlString) else { return }
        try? imageStorageService.deleteImage(at: url)
    }

    // MARK: - Private Helpers

    /// Crops an image to the specified bounding box with padding
    /// - Parameters:
    ///   - image: The source image to crop
    ///   - boundingBox: Normalized (0-1) bounding box from Vision framework
    /// - Returns: The cropped image, or nil if cropping fails
    private func cropImage(_ image: UIImage, boundingBox: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let imageSize = CGSize(
            width: CGFloat(cgImage.width),
            height: CGFloat(cgImage.height)
        )

        // Convert normalized boundingBox (0-1) to pixel coordinates
        // Vision uses bottom-left origin, UIImage uses top-left origin
        let convertedRect = convertVisionBoundingBox(boundingBox, imageSize: imageSize)

        // Add 15% padding on each side
        let paddedRect = addPadding(to: convertedRect, imageSize: imageSize, paddingPercent: 0.15)

        // Ensure crop rect is within image bounds
        let clampedRect = clampToImageBounds(paddedRect, imageSize: imageSize)

        // Validate minimum size
        guard clampedRect.width >= 100 && clampedRect.height >= 100 else {
            print("Cropped region too small: \(clampedRect)")
            return nil
        }

        // Perform the crop
        guard let croppedCGImage = cgImage.cropping(to: clampedRect) else {
            return nil
        }

        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Convert Vision's normalized bounding box (bottom-left origin, 0-1 coords)
    /// to UIImage pixel coordinates (top-left origin)
    private func convertVisionBoundingBox(_ boundingBox: CGRect, imageSize: CGSize) -> CGRect {
        // Vision uses normalized coordinates (0-1) with bottom-left origin
        // UIImage uses pixel coordinates with top-left origin

        let x = boundingBox.minX * imageSize.width
        let width = boundingBox.width * imageSize.width

        // Flip Y coordinate (Vision: bottom-left, UIImage: top-left)
        let yBottom = boundingBox.minY * imageSize.height
        let height = boundingBox.height * imageSize.height
        let yTop = imageSize.height - yBottom - height

        return CGRect(x: x, y: yTop, width: width, height: height)
    }

    /// Add padding to a rect while respecting image bounds
    private func addPadding(to rect: CGRect, imageSize: CGSize, paddingPercent: CGFloat) -> CGRect {
        let paddingX = rect.width * paddingPercent
        let paddingY = rect.height * paddingPercent

        return CGRect(
            x: rect.origin.x - paddingX,
            y: rect.origin.y - paddingY,
            width: rect.width + (paddingX * 2),
            height: rect.height + (paddingY * 2)
        )
    }

    /// Clamp rect to stay within image bounds
    private func clampToImageBounds(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        let x = max(0, min(rect.origin.x, imageSize.width - 1))
        let y = max(0, min(rect.origin.y, imageSize.height - 1))

        let maxWidth = imageSize.width - x
        let maxHeight = imageSize.height - y

        let width = max(0, min(rect.width, maxWidth))
        let height = max(0, min(rect.height, maxHeight))

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Save cropped barcode image to disk
    private func saveCroppedBarcodeImage(_ image: UIImage, cardId: String) throws -> URL {
        // Get documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDirectory = documentsPath.appendingPathComponent("CardImages", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        // Generate filename
        let filename = "cropped_barcode_\(cardId).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)

        // Convert to JPEG with 0.9 quality
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw ImageStorageError.conversionFailed
        }

        // Write to disk
        try imageData.write(to: fileURL)

        // Set Data Protection on the file
        try FileManager.default.setAttributes(
            [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path
        )

        return fileURL
    }
}
