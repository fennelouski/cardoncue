# Closest Card Widget

A beautiful, automatically-updating iOS widget that displays your membership card barcode for the nearest location.

## Features

✨ **Automatic Location-Based Updates** - Shows the card closest to your current location  
🎨 **App Design System** - Uses the same colors, fonts, and styling as the main app  
📱 **Multiple Sizes** - Supports small, medium, and large widget sizes  
🔒 **Secure** - Card data is decrypted on-demand using device keychain  
⚡ **Background Updates** - Refreshes automatically every 15 minutes or when location changes  

## Files Created

- `ClosestCardWidget.swift` - Main widget implementation
- `WIDGET_SETUP.md` - Detailed setup instructions
- Updated `CardLiveActivityWidget.swift` - Added widget bundle configuration

## Quick Setup

### 1. Add Files to Widget Target

In Xcode, add these files to the `CardOnCueWidget` target:
- `CardOnCue/BarcodeType.swift`
- `CardOnCue/CardModel.swift`
- `CardOnCue/KeychainService.swift`
- `CardOnCue/AppColors.swift`
- `ios/Shared/Utils/BarcodeRenderer.swift`

### 2. Configure App Groups

1. Select main app target → Signing & Capabilities
2. Add "App Groups" capability
3. Create group: `group.com.cardoncue.app`
4. Repeat for widget extension target

### 3. Build and Run

The widget will appear in the widget gallery after building.

## How It Works

1. **Location Sharing**: `GeofenceManager` saves location to shared UserDefaults
2. **Widget Provider**: Reads location and finds closest card
3. **Decryption**: Decrypts card payload using KeychainService
4. **Rendering**: Generates barcode image using BarcodeRenderer
5. **Display**: Shows card with location info and barcode

## Widget Sizes

- **Small**: Compact barcode with card name
- **Medium**: Larger barcode with location details
- **Large**: Full-size barcode with complete information

## Design

The widget matches the app's design system:
- Background: `Color.appBackground`
- Primary text: `Color.appBlue`
- Accent: `Color.appPrimary`
- Secondary text: `Color.appLightGray`

## Privacy

- Location stored only in App Group UserDefaults (local)
- Card data decrypted on-device only
- No data sent to servers
- Widget is read-only (never modifies data)

## Troubleshooting

See `WIDGET_SETUP.md` for detailed troubleshooting steps.

