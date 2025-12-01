import Foundation
import UIKit

enum ImageStorageError: Error {
    case failedToSaveImage
    case failedToLoadImage
    case failedToDeleteImage
    case invalidImageData
    case directoryCreationFailed
}

class ImageStorageService {
    static let shared = ImageStorageService()

    private let fileManager = FileManager.default
    private let imageDirectory = "CardImages"
    private let barcodeDirectory = "BarcodeImages"
    private let frontCardDirectory = "FrontCardImages"

    private init() {
        createDirectoriesIfNeeded()
    }

    private func createDirectoriesIfNeeded() {
        let directories = [imageDirectory, barcodeDirectory, frontCardDirectory]

        for directory in directories {
            guard let directoryURL = getDirectoryURL(for: directory) else { continue }

            if !fileManager.fileExists(atPath: directoryURL.path) {
                do {
                    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                } catch {
                    print("Failed to create directory \(directory): \(error)")
                }
            }
        }
    }

    private func getDirectoryURL(for directory: String) -> URL? {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsURL.appendingPathComponent(directory)
    }

    func saveBarcodeImage(_ image: UIImage, cardId: String) throws -> String {
        return try saveImage(image, directory: barcodeDirectory, prefix: "barcode_\(cardId)")
    }

    func saveFrontCardImage(_ image: UIImage, cardId: String) throws -> String {
        return try saveImage(image, directory: frontCardDirectory, prefix: "front_\(cardId)")
    }

    private func saveImage(_ image: UIImage, directory: String, prefix: String) throws -> String {
        guard let directoryURL = getDirectoryURL(for: directory) else {
            throw ImageStorageError.directoryCreationFailed
        }

        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw ImageStorageError.invalidImageData
        }

        let filename = "\(prefix)_\(UUID().uuidString).jpg"
        let fileURL = directoryURL.appendingPathComponent(filename)

        do {
            try imageData.write(to: fileURL)
            return fileURL.path
        } catch {
            throw ImageStorageError.failedToSaveImage
        }
    }

    func loadImage(from path: String) throws -> UIImage {
        let fileURL = URL(fileURLWithPath: path)

        guard fileManager.fileExists(atPath: path) else {
            throw ImageStorageError.failedToLoadImage
        }

        guard let imageData = try? Data(contentsOf: fileURL),
              let image = UIImage(data: imageData) else {
            throw ImageStorageError.failedToLoadImage
        }

        return image
    }

    func deleteImage(at path: String) throws {
        let fileURL = URL(fileURLWithPath: path)

        guard fileManager.fileExists(atPath: path) else {
            return
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw ImageStorageError.failedToDeleteImage
        }
    }

    func applyEditingMetadata(_ image: UIImage, metadata: ImageEditingMetadata) -> UIImage {
        var editedImage = image

        if let cropRect = metadata.cropRect {
            editedImage = cropImage(editedImage, to: cropRect)
        }

        if metadata.rotationAngle != 0 {
            editedImage = rotateImage(editedImage, by: metadata.rotationAngle)
        }

        if metadata.contrastAdjustment != 1.0 || metadata.brightnessAdjustment != 0 {
            editedImage = adjustImageColors(
                editedImage,
                contrast: metadata.contrastAdjustment,
                brightness: metadata.brightnessAdjustment
            )
        }

        if let perspectivePoints = metadata.perspectiveCorrectionPoints, perspectivePoints.count == 4 {
            editedImage = applyPerspectiveCorrection(editedImage, points: perspectivePoints)
        }

        return editedImage
    }

    private func cropImage(_ image: UIImage, to rect: CGRect) -> UIImage {
        guard let cgImage = image.cgImage?.cropping(to: rect) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    private func rotateImage(_ image: UIImage, by angle: Double) -> UIImage {
        let radians = angle * .pi / 180

        var newSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .size
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return image }

        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        image.draw(in: CGRect(
            x: -image.size.width / 2,
            y: -image.size.height / 2,
            width: image.size.width,
            height: image.size.height
        ))

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return rotatedImage ?? image
    }

    private func adjustImageColors(_ image: UIImage, contrast: Double, brightness: Double) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(contrast, forKey: kCIInputContrastKey)
        filter?.setValue(brightness, forKey: kCIInputBrightnessKey)

        guard let outputImage = filter?.outputImage,
              let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }

    private func applyPerspectiveCorrection(_ image: UIImage, points: [CGPoint]) -> UIImage {
        guard points.count == 4,
              let ciImage = CIImage(image: image) else { return image }

        let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection")
        perspectiveCorrection?.setValue(ciImage, forKey: kCIInputImageKey)
        perspectiveCorrection?.setValue(CIVector(cgPoint: points[0]), forKey: "inputTopLeft")
        perspectiveCorrection?.setValue(CIVector(cgPoint: points[1]), forKey: "inputTopRight")
        perspectiveCorrection?.setValue(CIVector(cgPoint: points[2]), forKey: "inputBottomRight")
        perspectiveCorrection?.setValue(CIVector(cgPoint: points[3]), forKey: "inputBottomLeft")

        guard let outputImage = perspectiveCorrection?.outputImage,
              let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage)
    }

    func getImageSize(at path: String) -> CGSize? {
        guard let image = try? loadImage(from: path) else {
            return nil
        }
        return image.size
    }

    func getImageFileSize(at path: String) -> Int64? {
        let fileURL = URL(fileURLWithPath: path)

        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path) else {
            return nil
        }

        return attributes[.size] as? Int64
    }

    // MARK: - Barcode Cropping for Lock Screen

    /// Crops an image to just the barcode area with a small margin for better scanability.
    /// This is especially useful for lock screen widgets where you want to maximize barcode size.
    /// - Parameters:
    ///   - image: The original image containing the barcode
    ///   - normalizedBoundingBox: The bounding box from Vision framework (normalized 0-1, bottom-left origin)
    ///   - margin: Extra margin around barcode as a percentage (default 0.1 = 10%)
    /// - Returns: Cropped image focused on the barcode
    func cropToBarcode(_ image: UIImage, normalizedBoundingBox: CGRect, margin: CGFloat = 0.1) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Vision uses bottom-left origin, UIKit uses top-left origin
        // Convert from Vision coordinates to UIKit coordinates
        let visionBox = normalizedBoundingBox

        // Calculate actual pixel coordinates
        var cropRect = CGRect(
            x: visionBox.origin.x * imageSize.width,
            y: (1 - visionBox.origin.y - visionBox.height) * imageSize.height, // Flip Y coordinate
            width: visionBox.width * imageSize.width,
            height: visionBox.height * imageSize.height
        )

        // Add margin around the barcode (10% on each side by default)
        let marginX = cropRect.width * margin
        let marginY = cropRect.height * margin

        cropRect = cropRect.insetBy(dx: -marginX, dy: -marginY)

        // Ensure crop rect is within image bounds
        cropRect = cropRect.intersection(CGRect(origin: .zero, size: imageSize))

        // Crop the image
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return image
        }

        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Convenience method to load and crop a barcode image for lock screen display
    func loadBarcodeImageForLockScreen(from barcodeData: BarcodeImageData) throws -> UIImage {
        let originalImage = try loadImage(from: barcodeData.localFilePath)

        // Apply editing metadata first
        var processedImage = originalImage
        if let metadata = barcodeData.editingMetadata {
            processedImage = applyEditingMetadata(originalImage, metadata: metadata)
        }

        // Crop to barcode area if bounding box is available
        if let boundingBox = barcodeData.barcodeBoundingBox {
            processedImage = cropToBarcode(processedImage, normalizedBoundingBox: boundingBox, margin: 0.15)
        }

        return processedImage
    }
}
