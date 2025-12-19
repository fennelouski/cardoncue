import Foundation
import SwiftUI

/// Represents different types of icons that can be used for cards
enum CardIconType: String, Codable, Sendable {
    case automatic // Auto-assigned based on business name
    case sfSymbol // SF Symbol with optional color
    case image // Custom image (from scan, library, or camera)
    case emoji // Emoji character
    case text // Text rendered as image
    case drawing // User-drawn icon
}

/// Complete icon data structure
struct CardIcon: Sendable {
    var type: CardIconType
    var value: String // SF Symbol name, emoji, text, or image file path
    var colorHex: String? // For SF Symbols - hex color code
    var backgroundColorHex: String? // For SF Symbols - background color
    
    /// Create automatic icon
    static func automatic() -> CardIcon {
        CardIcon(type: .automatic, value: "", colorHex: nil, backgroundColorHex: nil)
    }
    
    /// Create SF Symbol icon
    static func sfSymbol(_ name: String, color: Color? = nil, backgroundColor: Color? = nil) -> CardIcon {
        CardIcon(
            type: .sfSymbol,
            value: name,
            colorHex: color?.toHex(),
            backgroundColorHex: backgroundColor?.toHex()
        )
    }
    
    /// Create image icon
    nonisolated static func image(_ filePath: String) -> CardIcon {
        CardIcon(type: .image, value: filePath, colorHex: nil, backgroundColorHex: nil)
    }
    
    /// Create emoji icon
    static func emoji(_ emoji: String) -> CardIcon {
        CardIcon(type: .emoji, value: emoji, colorHex: nil, backgroundColorHex: nil)
    }
    
    /// Create text icon
    static func text(_ text: String) -> CardIcon {
        CardIcon(type: .text, value: text, colorHex: nil, backgroundColorHex: nil)
    }
    
    /// Create drawing icon
    static func drawing(_ filePath: String) -> CardIcon {
        CardIcon(type: .drawing, value: filePath, colorHex: nil, backgroundColorHex: nil)
    }
}

extension Color {
    /// Convert Color to hex string
    func toHex() -> String? {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        guard let components = uiColor.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        let a = components.count >= 4 ? Int(components[3] * 255) : 255
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        #else
        return nil
        #endif
    }
    
    /// Create Color from hex string
    static func fromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let r, g, b, a: CGFloat
        if hexSanitized.count == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255
            a = CGFloat(rgb & 0x000000FF) / 255
        } else if hexSanitized.count == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255
            b = CGFloat(rgb & 0x0000FF) / 255
            a = 1.0
        } else {
            return nil
        }
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Codable Conformance
extension CardIcon: Codable {
    enum CodingKeys: String, CodingKey {
        case type, value, colorHex, backgroundColorHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(CardIconType.self, forKey: .type)
        value = try container.decode(String.self, forKey: .value)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        backgroundColorHex = try container.decodeIfPresent(String.self, forKey: .backgroundColorHex)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(value, forKey: .value)
        try container.encodeIfPresent(colorHex, forKey: .colorHex)
        try container.encodeIfPresent(backgroundColorHex, forKey: .backgroundColorHex)
    }
}

