import SwiftUI

/// Color scheme for watchOS app - optimized for watch displays
extension Color {
    /// Primary accent color for watchOS (matches iOS app)
    static var watchPrimary: Color {
        Color.blue
    }
    
    /// Secondary accent color
    static var watchSecondary: Color {
        Color.green
    }
    
    /// Background color for cards/badges
    static var watchCardBackground: Color {
        Color.secondary.opacity(0.1)
    }
    
    /// Background for barcode display area
    static var watchBarcodeBackground: Color {
        Color.white.opacity(0.95)
    }
    
    /// Success/active state color
    static var watchSuccess: Color {
        Color.green
    }
    
    /// Warning/info color
    static var watchInfo: Color {
        Color.blue
    }
}


