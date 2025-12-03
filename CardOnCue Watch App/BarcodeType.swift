import Foundation

/// Supported barcode types (shared with iOS app)
enum BarcodeType: String, Codable {
    case qr
    case code128
    case pdf417
    case aztec
    case ean13
    case upcA = "upc_a"
    case code39
    case itf
    
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
}

