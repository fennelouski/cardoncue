import UIKit
import CoreImage

class BarcodeRenderer {
    enum BarcodeError: Error {
        case invalidData
        case generationFailed
        case unsupportedType
    }

    func render(payload: String, type: BarcodeType, size: CGSize) throws -> UIImage {
        let filter = try createFilter(for: type)

        guard let data = payload.data(using: .ascii) else {
            throw BarcodeError.invalidData
        }

        filter.setValue(data, forKey: "inputMessage")

        guard let outputImage = filter.outputImage else {
            throw BarcodeError.generationFailed
        }

        let scaleX = size.width / outputImage.extent.width
        let scaleY = size.height / outputImage.extent.height
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        let scaledImage = outputImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw BarcodeError.generationFailed
        }

        return UIImage(cgImage: cgImage)
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
