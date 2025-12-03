# watchOS App Setup Guide

This guide explains how to add the watchOS app target to your Xcode project so that CardOnCue can display barcodes on Apple Watch when users arrive at locations.

## Features

The watchOS app provides:
- **Automatic barcode display** when arriving at a geofenced location
- **Brightness control** for optimal scanner readability
- **Location context** showing which store/location triggered the card
- **Support for all barcode types** (QR, Code128, PDF417, Aztec)

## Adding the watchOS Target in Xcode

### Step 1: Create Watch App Target

1. Open your project in Xcode
2. Go to **File → New → Target**
3. Select **watchOS → App** and click **Next**
4. Configure:
   - **Product Name**: `CardOnCue Watch App`
   - **Bundle Identifier**: `app.cardoncue.CardOnCue.watchkitapp`
   - **Language**: Swift
   - **Interface**: SwiftUI
   - **Include Notification Scene**: ✅ (checked)
5. Click **Finish**

### Step 2: Add Source Files

1. Add all files from the `CardOnCue Watch App/` directory to the new watchOS target:
   - `CardOnCueWatchApp.swift`
   - `ContentView.swift`
   - `BarcodeDisplayView.swift`
   - `WatchBarcodeImageView.swift`
   - `WatchBarcodeRenderer.swift`
   - `WatchNotificationManager.swift`
   - `BarcodeType.swift`
   - `Info.plist`

2. Make sure these files are added to the **CardOnCue Watch App** target (not the iOS target)

### Step 3: Configure Capabilities

1. Select the **CardOnCue Watch App** target
2. Go to **Signing & Capabilities**
3. Ensure:
   - **Automatically manage signing** is enabled
   - Same **Team** as the iOS app
   - Bundle identifier matches: `app.cardoncue.CardOnCue.watchkitapp`

### Step 4: Configure Info.plist

The `Info.plist` should already be configured with:
- `WKCompanionAppBundleIdentifier`: `app.cardoncue.CardOnCue`
- `WKApplication`: `true`

### Step 5: Build and Run

1. Select the **CardOnCue Watch App** scheme
2. Choose a watchOS simulator or device
3. Build and run (⌘ + R)

## How It Works

1. **iOS app** monitors location via `GeofenceManager`
2. When user enters a geofenced region, iOS sends a local notification
3. Notification includes:
   - Card ID, name, barcode type
   - **Decrypted barcode payload** (for watchOS display)
   - Location name
4. **watchOS app** receives notification via `WatchNotificationManager`
5. watchOS app decrypts and displays the barcode using `WatchBarcodeRenderer`
6. User can adjust brightness for optimal scanner readability

## Security Considerations

- Barcode payloads are **decrypted on iOS** before sending to watchOS
- Notifications are **local only** (iOS → watchOS on same device)
- No data leaves the user's device ecosystem
- Decryption happens only when needed for display

## Testing

1. **Simulate location entry**:
   - Use Xcode's location simulation
   - Or physically visit a geofenced location

2. **Verify notification**:
   - Notification should appear on watch
   - Tapping notification should show barcode

3. **Test barcode display**:
   - Verify barcode renders correctly
   - Test brightness adjustment
   - Verify location name displays

## Troubleshooting

### Notification not appearing
- Check that notification permissions are granted
- Verify `WKCompanionAppBundleIdentifier` matches iOS app bundle ID
- Ensure iOS app is running or has background location permission

### Barcode not rendering
- Check that payload is included in notification userInfo
- Verify barcode type is supported (QR, Code128, PDF417, Aztec)
- Check console logs for decryption errors

### Build errors
- Ensure all watchOS files are added to correct target
- Verify imports are correct (UIKit vs WatchKit)
- Check that CryptoKit is available (watchOS 7.0+)

## Requirements

- **watchOS**: 7.0 or later
- **iOS**: 14.0 or later (for companion app)
- **Xcode**: 12.0 or later

