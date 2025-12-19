import Foundation
import UIKit
import PencilKit

/// Service for storing card images to local file system with iOS Data Protection
class CardImageStorageService {
    static let shared = CardImageStorageService()

    private let imagesDirectory: URL

    // Image cache with memory limits
    private let imageCache = NSCache<NSString, UIImage>()
    private let cacheQueue = DispatchQueue(label: "com.cardoncue.imageCache", qos: .userInitiated)

    private init() {
        // Create images directory in app's documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        imagesDirectory = documentsPath.appendingPathComponent("CardImages", isDirectory: true)

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        // Set Data Protection on the directory
        try? FileManager.default.setAttributes(
            [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: imagesDirectory.path
        )

        // Configure cache limits to prevent memory bloat
        imageCache.countLimit = 20  // Maximum 20 images in cache
        imageCache.totalCostLimit = 50 * 1024 * 1024  // 50 MB total cache size

        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func clearCache() {
        cacheQueue.async { [weak self] in
            self?.imageCache.removeAllObjects()
        }
    }
    
    /// Save an image to disk and return its file URL
    /// - Parameters:
    ///   - image: The image to save
    ///   - cardId: The card ID to use in the filename
    ///   - isProcessed: Whether this is the processed version (false for original)
    /// - Returns: The file URL where the image was saved
    func saveImage(_ image: UIImage, cardId: String, isProcessed: Bool) throws -> URL {
        // Generate filename: cardId_original.jpg or cardId_processed.jpg
        let suffix = isProcessed ? "processed" : "original"
        let filename = "\(cardId)_\(suffix).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        // Convert to JPEG with high quality
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
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
    
    /// Load an image from disk with caching
    /// - Parameter url: The file URL of the image
    /// - Returns: The loaded image, or nil if not found
    func loadImage(from url: URL) -> UIImage? {
        let cacheKey = url.lastPathComponent as NSString

        // Check cache first
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            return cachedImage
        }

        // Load from disk
        guard let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            return nil
        }

        // Estimate memory cost (width * height * 4 bytes per pixel)
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)

        // Cache the image with cost
        imageCache.setObject(image, forKey: cacheKey, cost: cost)

        return image
    }
    
    /// Delete an image file
    /// - Parameter url: The file URL of the image to delete
    func deleteImage(at url: URL) throws {
        // Remove from cache
        let cacheKey = url.lastPathComponent as NSString
        imageCache.removeObject(forKey: cacheKey)

        // Delete from disk
        try FileManager.default.removeItem(at: url)
    }
    
    /// Delete all images for a card
    /// - Parameter cardId: The card ID
    func deleteImages(for cardId: String) {
        let originalURL = imagesDirectory.appendingPathComponent("\(cardId)_original.jpg")
        let processedURL = imagesDirectory.appendingPathComponent("\(cardId)_processed.jpg")

        try? deleteImage(at: originalURL)
        try? deleteImage(at: processedURL)

        // Also delete cropped barcode image
        deleteCroppedBarcodeImage(for: cardId)
    }

    /// Delete cropped barcode image for a card
    /// - Parameter cardId: The card ID
    func deleteCroppedBarcodeImage(for cardId: String) {
        let filename = "cropped_barcode_\(cardId).jpg"
        let url = imagesDirectory.appendingPathComponent(filename)
        try? deleteImage(at: url)
    }
    
    /// Get the file URL for a card image without loading it
    /// - Parameters:
    ///   - cardId: The card ID
    ///   - isProcessed: Whether to get the processed version URL
    /// - Returns: The file URL, or nil if file doesn't exist
    func getImageURL(cardId: String, isProcessed: Bool) -> URL? {
        let suffix = isProcessed ? "processed" : "original"
        let filename = "\(cardId)_\(suffix).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    /// Save an icon image
    /// - Parameters:
    ///   - image: The icon image to save
    ///   - cardId: The card ID
    /// - Returns: The file URL where the icon was saved
    func saveIconImage(_ image: UIImage, cardId: String) throws -> URL {
        let filename = "\(cardId)_icon.jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        // Convert to JPEG with high quality
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
    
    /// Get the icon image URL for a card
    /// - Parameter cardId: The card ID
    /// - Returns: The file URL, or nil if icon doesn't exist
    func getIconImageURL(cardId: String) -> URL? {
        let filename = "\(cardId)_icon.jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    /// Delete icon image for a card
    /// - Parameter cardId: The card ID
    func deleteIconImage(for cardId: String) {
        let iconURL = imagesDirectory.appendingPathComponent("\(cardId)_icon.jpg")
        try? deleteImage(at: iconURL)
    }
    
    /// Save a PKDrawing to disk for future editing
    /// - Parameters:
    ///   - drawing: The PKDrawing to save
    ///   - cardId: The card ID
    /// - Returns: The file URL where the drawing was saved
    func saveDrawingData(_ drawing: PKDrawing, cardId: String) throws -> URL {
        let filename = "\(cardId)_drawing.pkdrawing"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        // PKDrawing can be encoded to Data
        let drawingData = drawing.dataRepresentation()
        
        // Write to disk
        try drawingData.write(to: fileURL)
        
        // Set Data Protection on the file
        try FileManager.default.setAttributes(
            [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path
        )
        
        return fileURL
    }
    
    /// Load a PKDrawing from disk
    /// - Parameter cardId: The card ID
    /// - Returns: The loaded PKDrawing, or nil if not found
    func loadDrawingData(cardId: String) -> PKDrawing? {
        let filename = "\(cardId)_drawing.pkdrawing"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let drawingData = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        return try? PKDrawing(data: drawingData)
    }
    
    /// Delete drawing data for a card
    /// - Parameter cardId: The card ID
    func deleteDrawingData(for cardId: String) {
        let drawingURL = imagesDirectory.appendingPathComponent("\(cardId)_drawing.pkdrawing")
        try? deleteImage(at: drawingURL)
    }
    
    /// Get the drawing file URL for a card
    /// - Parameter cardId: The card ID
    /// - Returns: The file URL, or nil if drawing doesn't exist
    func getDrawingDataURL(cardId: String) -> URL? {
        let filename = "\(cardId)_drawing.pkdrawing"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
}

enum ImageStorageError: LocalizedError {
    case conversionFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .conversionFailed:
            return "Failed to convert image to JPEG format"
        case .saveFailed:
            return "Failed to save image to disk"
        }
    }
}


