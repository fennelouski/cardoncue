# Widget Setup Guide

This guide explains how to set up the Closest Card Widget that automatically displays your membership card barcode for the nearest location.

## Overview

The Closest Card Widget:
- Automatically updates in the background based on your location
- Shows the barcode/QR code for the card closest to your current location
- Uses the same design system and colors as the main app
- Updates every 15 minutes or when location changes significantly

## Xcode Project Setup

### 1. Add Files to Widget Extension Target

The widget extension needs access to several shared files. Add these files to the `CardOnCueWidget` target:

**Required Files (add to widget target):**
- `CardOnCue/BarcodeType.swift`
- `CardOnCue/CardModel.swift`
- `CardOnCue/KeychainService.swift`
- `CardOnCue/AppColors.swift` (or ensure Color extensions are accessible)
- `ios/Shared/Utils/BarcodeRenderer.swift`

**To add files to target:**
1. Select the file in Xcode
2. Open File Inspector (⌥⌘1)
3. Under "Target Membership", check `CardOnCueWidget`

### 2. Configure App Groups

App Groups allow the main app and widget to share location data.

1. In Xcode, select the main app target (`CardOnCue`)
2. Go to "Signing & Capabilities"
3. Click "+ Capability" and add "App Groups"
4. Create a group: `group.com.cardoncue.app`
5. Repeat for the widget extension target (`CardOnCueWidget`)

**Important:** Both targets must use the same App Group identifier.

### 3. Widget Bundle Configuration

The widget bundle (`CardOnCueWidgets`) includes:
- `CardLiveActivityWidget` - Live Activity widget (existing)
- `ClosestCardWidget` - New home screen widget (this widget)

Both widgets are registered in `CardLiveActivityWidget.swift`:

```swift
@main
struct CardOnCueWidgets: WidgetBundle {
    var body: some Widget {
        CardLiveActivityWidget()
        ClosestCardWidget()
    }
}
```

### 4. Info.plist Configuration

Ensure the widget extension's `Info.plist` includes:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
</dict>
```

## How It Works

### Location Sharing

1. **Main App** (`GeofenceManager`):
   - Updates location via `CLLocationManager`
   - Saves location to `UserDefaults` with App Group: `group.com.cardoncue.app`
   - Keys: `lastKnownLatitude`, `lastKnownLongitude`, `lastLocationUpdate`

2. **Widget Extension** (`ClosestCardTimelineProvider`):
   - Reads location from shared `UserDefaults`
   - Finds closest card with location data
   - Decrypts card payload using `KeychainService`
   - Generates barcode image using `BarcodeRenderer`
   - Updates widget timeline

### Card Selection Logic

The widget selects the closest card using this priority:

1. **Cards with location data**: Finds card with `locationLatitude` and `locationLongitude` closest to current location
2. **Fallback**: If no cards have location data, shows the most recently updated card
3. **Error state**: If no cards available or decryption fails, shows error message

### Timeline Updates

- **Default**: Updates every 15 minutes
- **Location-based**: Can update more frequently when location changes significantly
- **Manual**: User can force refresh by removing and re-adding widget

## Widget Sizes

The widget supports three sizes:

- **Small**: Shows card name, location, and barcode
- **Medium**: More space for barcode and additional details
- **Large**: Full barcode display with location information

## Design System

The widget uses the same design system as the main app:

- **Colors**: `Color.appBackground`, `Color.appBlue`, `Color.appPrimary`, `Color.appLightGray`
- **Typography**: `.headline`, `.caption`, `.caption2` matching app styles
- **Icons**: SF Symbols matching app iconography
- **Layout**: Consistent spacing and padding

## Privacy & Security

- **Location**: Only stored locally in App Group UserDefaults, never sent to server
- **Encryption**: Card payloads are decrypted on-demand using device keychain
- **Access**: Widget only reads data, never modifies cards or location

## Troubleshooting

### Widget shows "Location unavailable"

1. Ensure location permissions are granted in Settings > CardOnCue > Location
2. Open the main app to trigger location update
3. Check that App Groups are configured correctly

### Widget shows "Unable to decrypt card"

1. Ensure device is unlocked (keychain requires authentication)
2. Check that cards exist in the app
3. Verify KeychainService is accessible to widget target

### Widget doesn't update

1. Check widget refresh policy (iOS controls update frequency)
2. Force refresh by removing and re-adding widget
3. Ensure location is updating in main app

### Barcode not displaying

1. Verify BarcodeRenderer is added to widget target
2. Check that barcode type is supported (QR, Code128, PDF417, Aztec)
3. Ensure payload is valid

## Testing

1. **Add Widget**:
   - Long press on home screen
   - Tap "+" button
   - Search for "CardOnCue"
   - Select "Closest Card" widget
   - Choose size and add

2. **Test Location Updates**:
   - Grant location permission
   - Open main app to trigger location update
   - Widget should update within 15 minutes

3. **Test Card Selection**:
   - Add cards with location data
   - Move to different locations (or simulate in simulator)
   - Widget should show closest card

## Future Enhancements

Potential improvements:
- Multiple widget sizes with different layouts
- Tap to open card in app
- Show multiple nearby cards
- Customizable update frequency
- Widget configuration options

