import Foundation
import UIKit

/// Service for storing card images to local file system with iOS Data Protection
class CardImageStorageService {
    static let shared = CardImageStorageService()
    
    private let imagesDirectory: URL
    
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
    
    /// Load an image from disk
    /// - Parameter url: The file URL of the image
    /// - Returns: The loaded image, or nil if not found
    func loadImage(from url: URL) -> UIImage? {
        guard let imageData = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: imageData)
    }
    
    /// Delete an image file
    /// - Parameter url: The file URL of the image to delete
    func deleteImage(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    /// Delete all images for a card
    /// - Parameter cardId: The card ID
    func deleteImages(for cardId: String) {
        let originalURL = imagesDirectory.appendingPathComponent("\(cardId)_original.jpg")
        let processedURL = imagesDirectory.appendingPathComponent("\(cardId)_processed.jpg")
        
        try? deleteImage(at: originalURL)
        try? deleteImage(at: processedURL)
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

