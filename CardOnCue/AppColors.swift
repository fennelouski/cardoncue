//
//  AppColors.swift
//  CardOnCue
//
//  Color scheme based on the app icon
//  Note: Xcode auto-generates Color extensions for assets in the catalog.
//  These are convenience aliases that match the auto-generated names.
//

import SwiftUI

// Xcode automatically generates these Color extensions from Assets.xcassets:
// - Color.accentColor (from AccentColor)
// - Color.appBlue (from AppBlue)
// - Color.appGreen (from AppGreen)
// - Color.appBeige (from AppBeige)
// - Color.appCream (from AppCream)
// - Color.appLightGray (from AppLightGray)
// - Color.appBackground (from AppBackground)

extension Color {
    /// Primary red color from the app icon (location pin)
    /// Alias for the AccentColor asset.
    static var appPrimary: Color { .accentColor }

    // Named color sets from Assets.xcassets. Loaded by name so they work
    // regardless of whether Xcode asset-symbol generation is enabled.
    static let appBlue = Color("AppBlue")
    static let appGreen = Color("AppGreen")
    static let appBeige = Color("AppBeige")
    static let appCream = Color("AppCream")
    static let appLightGray = Color("AppLightGray")
    static let appBackground = Color("AppBackground")
}

