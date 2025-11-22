import Foundation

/// Supported barcode types
enum BarcodeType: String, Codable, CaseIterable {
    case qr
    case code128
    case pdf417
    case aztec
    case ean13
    case upcA = "upc_a"
    case code39
    case itf

    /// Human-readable name
    var displayName: String {
        switch self {
        case .qr: return "QR Code"
        case .code128: return "Code 128"
        case .pdf417: return "PDF417"
        case .aztec: return "Aztec"
        case .ean13: return "EAN-13"
        case .upcA: return "UPC-A"
        case .code39: return "Code 39"
        case .itf: return "ITF"
        }
    }

    /// CoreImage filter name (if available)
    var coreImageFilterName: String? {
        switch self {
        case .qr: return "CIQRCodeGenerator"
        case .code128: return "CICode128BarcodeGenerator"
        case .pdf417: return "CIPDF417BarcodeGenerator"
        case .aztec: return "CIAztecCodeGenerator"
        default: return nil // Not supported by CoreImage, use fallback renderer
        }
    }
}
