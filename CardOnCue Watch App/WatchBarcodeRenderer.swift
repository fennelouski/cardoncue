import CoreGraphics
import QRCodeGenerator
#if os(watchOS)
import WatchKit
#endif

/// Barcode renderer for watchOS (CoreImage is unavailable on watch).
class WatchBarcodeRenderer {
    static let shared = WatchBarcodeRenderer()

    private var imageCache: [String: CGImage] = [:]
    private let cacheQueue = DispatchQueue(label: "com.cardoncue.barcodeCache", attributes: .concurrent)

    enum BarcodeError: Error {
        case invalidData
        case generationFailed
        case unsupportedType
    }

    private init() {}

    func render(payload: String, type: BarcodeType, size: CGSize) throws -> CGImage {
        let cacheKey = "\(payload)_\(type.rawValue)_\(size.width)x\(size.height)"

        if let cached = cacheQueue.sync(execute: { imageCache[cacheKey] }) {
            return cached
        }

        let cgImage = try generateImage(payload: payload, type: type, size: size)

        cacheQueue.async(flags: .barrier) {
            if self.imageCache.count >= 5, let firstKey = self.imageCache.keys.first {
                self.imageCache.removeValue(forKey: firstKey)
            }
            self.imageCache[cacheKey] = cgImage
        }

        return cgImage
    }

    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.imageCache.removeAll()
        }
    }

    private func generateImage(payload: String, type: BarcodeType, size: CGSize) throws -> CGImage {
        switch type {
        case .qr:
            return try renderQRCode(payload: payload, size: size)
        case .code128, .ean13, .upcA, .code39, .itf:
            return try LinearBarcodeRenderer.render(payload: payload, type: type, size: size)
        // ponytail: PDF417/Aztec are 2D and rare for loyalty cards; add a watch 2D encoder if a card needs one.
        case .pdf417, .aztec:
            throw BarcodeError.unsupportedType
        }
    }

    private func renderQRCode(payload: String, size: CGSize) throws -> CGImage {
        guard !payload.isEmpty else {
            throw BarcodeError.invalidData
        }

        let qr = try QRCode.encode(text: payload, ecl: .medium)
        let targetDimension = max(Int(size.width.rounded()), Int(size.height.rounded()), qr.size)
        let modulePixelSize = max(1, targetDimension / qr.size)
        let imageDimension = qr.size * modulePixelSize

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: imageDimension,
            height: imageDimension,
            bitsPerComponent: 8,
            bytesPerRow: imageDimension,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw BarcodeError.generationFailed
        }

        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: imageDimension, height: imageDimension))
        context.setFillColor(gray: 0, alpha: 1)

        for y in 0..<qr.size {
            for x in 0..<qr.size where qr.getModule(x: x, y: y) {
                context.fill(CGRect(
                    x: x * modulePixelSize,
                    y: y * modulePixelSize,
                    width: modulePixelSize,
                    height: modulePixelSize
                ))
            }
        }

        guard let image = context.makeImage() else {
            throw BarcodeError.generationFailed
        }
        return image
    }
}
