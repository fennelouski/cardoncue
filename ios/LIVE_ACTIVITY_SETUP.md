# Live Activity Setup Guide

This guide explains how to configure and use the iOS Live Activity feature for CardOnCue.

## Overview

Live Activities display card barcodes on the Lock Screen and in the Dynamic Island, allowing users to quickly access their cards without opening the app.

## Xcode Project Setup

### 1. Create Widget Extension Target

1. In Xcode, go to `File > New > Target`
2. Choose `Widget Extension` template
3. Name it `CardOnCueWidget`
4. **Important:** Uncheck "Include Configuration Intent"
5. Click Finish

### 2. Add Files to Targets

Add the following files to both the main app and widget extension targets:

**Shared Files (add to both targets):**
- `ios/Shared/Models/Card.swift`
- `ios/Shared/Models/CardLiveActivityAttributes.swift`
- `ios/Shared/Utils/BarcodeRenderer.swift`

**Main App Only:**
- `ios/CardOnCue/Services/LiveActivityService.swift`
- `ios/CardOnCue/Views/CardDetailView.swift`

**Widget Extension Only:**
- `ios/CardOnCueWidget/CardLiveActivityWidget.swift`

To add files to targets:
1. Select the file in Xcode
2. Open File Inspector (⌥⌘1)
3. Under "Target Membership", check the appropriate targets

### 3. Configure Info.plist Files

#### Main App Info.plist

Add support for Live Activities by adding this key-value pair:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

Or in Xcode:
1. Open `Info.plist`
2. Add a new row
3. Key: `Supports Live Activities` (NSSupportsLiveActivities)
4. Type: Boolean
5. Value: YES

#### Widget Extension Info.plist

The widget extension Info.plist should already be configured correctly by Xcode, but ensure it contains:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
</dict>
```

### 4. Configure App Groups (Optional but Recommended)

For sharing data between the main app and widget:

1. In project settings, select the main app target
2. Go to "Signing & Capabilities"
3. Click "+ Capability" and add "App Groups"
4. Create a group: `group.com.yourcompany.cardoncue`
5. Repeat for the widget extension target

### 5. Build and Run

1. Select a physical device or iOS 16.1+ simulator
2. Build the project (⌘B)
3. Run the app (⌘R)

## Usage

### Starting a Live Activity

1. Open the app
2. Tap on a card from your list
3. Scroll to the "Live Activity" section
4. Tap "Start Live Activity"

The barcode will now appear:
- On your Lock Screen
- In the Dynamic Island (iPhone 14 Pro and newer)
- In the notification center

### Adjusting Brightness

Use the brightness slider in the app to adjust the barcode brightness in real-time. This is useful for:
- Bright outdoor environments (increase brightness)
- Dark rooms with sensitive scanners (decrease brightness)
- Different scanner types

### Stopping a Live Activity

Tap "Stop Live Activity" in the card detail view, or dismiss it from the Lock Screen/Dynamic Island.

## Features

### Lock Screen View
- Card name and barcode type
- Rendered barcode
- Brightness indicator
- Last update timestamp

### Dynamic Island (iPhone 14 Pro+)

**Compact View:**
- Barcode icon
- Card name

**Expanded View:**
- Full barcode display
- Card information
- Brightness control
- Update timestamp

**Minimal View:**
- Barcode icon only

## Supported Barcode Types

The following barcode types are supported in Live Activities:
- QR Code
- Code 128
- PDF417
- Aztec

Note: EAN-13, UPC-A, Code 39, and ITF require iOS rendering capabilities and may not display in all contexts.

## Troubleshooting

### Live Activity won't start

1. **Check iOS version**: Live Activities require iOS 16.1 or later
2. **Check Settings**:
   - Go to Settings > CardOnCue
   - Ensure "Live Activities" is enabled
3. **Check system settings**:
   - Go to Settings > Face ID & Passcode (or Touch ID & Passcode)
   - Ensure "Live Activities" is enabled

### Barcode not displaying correctly

1. Try adjusting the brightness slider
2. Ensure the barcode payload is valid
3. Check that the barcode type is supported

### Widget extension not found

1. Clean build folder (⌘⇧K)
2. Delete app from device/simulator
3. Rebuild and reinstall

## Technical Details

### Architecture

```
┌─────────────────┐
│   Main App      │
│  ┌───────────┐  │
│  │LiveActivity│  │
│  │  Service   │──┼──> Start/Update/End
│  └───────────┘  │
└─────────────────┘
        │
        │ Activity Framework
        ▼
┌─────────────────┐
│ Widget Extension│
│  ┌───────────┐  │
│  │ Live      │  │
│  │ Activity  │  │
│  │ Widget    │  │
│  └───────────┘  │
│  ┌───────────┐  │
│  │ Barcode   │  │
│  │ Renderer  │  │
│  └───────────┘  │
└─────────────────┘
```

### Data Flow

1. User taps "Start Live Activity" in CardDetailView
2. LiveActivityService creates activity with CardLiveActivityAttributes
3. ActivityKit sends attributes to widget extension
4. Widget extension renders barcode using BarcodeRenderer
5. Updates are pushed to widget when brightness changes

### State Management

- **Activity Attributes** (static): Card ID, name, barcode type, payload
- **Content State** (dynamic): Brightness level, last update timestamp

## Limitations

- Maximum of 8 hours per Live Activity session
- Only one Live Activity can be active at a time in this implementation
- Requires iOS 16.1 or later
- Dynamic Island views only available on iPhone 14 Pro and newer

## Future Enhancements

Potential improvements:
- Multiple simultaneous Live Activities for different cards
- Push notification updates from server
- Geofence-triggered Live Activities
- NFC integration for contactless payments
- Apple Watch complications

## Resources

- [Apple Documentation: ActivityKit](https://developer.apple.com/documentation/activitykit)
- [WWDC: Meet ActivityKit](https://developer.apple.com/videos/play/wwdc2023/10184/)
- [Human Interface Guidelines: Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)
