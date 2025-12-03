import UIKit
import CoreImage
#if os(watchOS)
import WatchKit
#endif

/// Barcode renderer for watchOS with performance optimizations
class WatchBarcodeRenderer {
    static let shared = WatchBarcodeRenderer()
    
    // Reusable CIContext for better performance
    private let ciContext: CIContext
    
    // Cache for rendered barcode images (keyed by payload+type+size)
    private var imageCache: [String: UIImage] = [:]
    private let cacheQueue = DispatchQueue(label: "com.cardoncue.barcodeCache", attributes: .concurrent)
    
    enum BarcodeError: Error {
        case invalidData
        case generationFailed
        case unsupportedType
    }
    
    private init() {
        // Use optimized CIContext options for watchOS
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .cacheIntermediates: false // Save memory on watch
        ]
        self.ciContext = CIContext(options: options)
    }
    
    func render(payload: String, type: BarcodeType, size: CGSize) throws -> UIImage {
        // Check cache first
        let cacheKey = "\(payload)_\(type.rawValue)_\(size.width)x\(size.height)"
        
        var cachedImage: UIImage?
        cacheQueue.sync {
            cachedImage = imageCache[cacheKey]
        }
        
        if let cached = cachedImage {
            return cached
        }
        
        // Generate new image
        let filter = try createFilter(for: type)
        
        guard let data = payload.data(using: .ascii) else {
            throw BarcodeError.invalidData
        }
        
        filter.setValue(data, forKey: "inputMessage")
        
        // For QR codes, set correction level
        if type == .qr {
            filter.setValue("M", forKey: "inputCorrectionLevel")
        }
        
        guard let outputImage = filter.outputImage else {
            throw BarcodeError.generationFailed
        }
        
        // Optimize scale calculation for watch screen sizes
        let scaleX = size.width / outputImage.extent.width
        let scaleY = size.height / outputImage.extent.height
        let scale = min(scaleX, scaleY)
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)
        
        // Use shared CIContext for better performance
        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw BarcodeError.generationFailed
        }
        
        let image = UIImage(cgImage: cgImage)
        
        // Cache the image (limit cache size)
        cacheQueue.async(flags: .barrier) {
            // Limit cache to 5 images to save memory
            if self.imageCache.count >= 5 {
                // Remove oldest entry (simple FIFO)
                if let firstKey = self.imageCache.keys.first {
                    self.imageCache.removeValue(forKey: firstKey)
                }
            }
            self.imageCache[cacheKey] = image
        }
        
        return image
    }
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.imageCache.removeAll()
        }
    }
    
    private func createFilter(for type: BarcodeType) throws -> CIFilter {
        let filterName: String
        
        switch type {
        case .qr:
            filterName = "CIQRCodeGenerator"
        case .code128:
            filterName = "CICode128BarcodeGenerator"
        case .pdf417:
            filterName = "CIPDF417BarcodeGenerator"
        case .aztec:
            filterName = "CIAztecCodeGenerator"
        default:
            throw BarcodeError.unsupportedType
        }
        
        guard let filter = CIFilter(name: filterName) else {
            throw BarcodeError.generationFailed
        }
        
        return filter
    }
}

