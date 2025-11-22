# CardOnCue iOS App

Privacy-first, location-aware digital wallet for membership cards.

## Requirements

- Xcode 15.0+
- iOS 17.0+
- Swift 5.9+
- CocoaPods or Swift Package Manager

## Project Setup

### 1. Create Xcode Project

Since the Xcode project file (`.xcodeproj`) is binary and auto-generated, you'll need to create it manually:

1. Open Xcode
2. File → New → Project
3. Choose "App" template (iOS)
4. Product Name: **CardOnCue**
5. Organization Identifier: **app.cardoncue**
6. Interface: **SwiftUI**
7. Language: **Swift**
8. Save to: `CardOnCue/ios/`

### 2. Add Source Files

The project structure is already created in this directory:

```
ios/CardOnCue/
├── Features/
│   ├── Scanner/
│   │   ├── BarcodeScannerView.swift
│   │   └── ScannerViewModel.swift
│   ├── Cards/
│   │   ├── CardListView.swift
│   │   ├── CardDetailView.swift
│   │   └── CardViewModel.swift
│   ├── LocationManager/
│   │   └── LocationViewModel.swift
│   └── WalletIntegration/
│       └── PassKitExporter.swift
├── Services/
│   ├── BarcodeService.swift
│   ├── LocationService.swift
│   ├── StorageService.swift
│   ├── APIClient.swift
│   └── KeychainService.swift
├── Models/
│   ├── Card.swift
│   ├── Network.swift
│   ├── Location.swift
│   └── BarcodeType.swift
├── Views/
│   ├── BarcodeView.swift
│   └── CardSelectorView.swift
└── Utilities/
    ├── BarcodeRenderer.swift
    └── EncryptionHelper.swift
```

**In Xcode**:
1. Right-click on "CardOnCue" in Project Navigator
2. Add Files to "CardOnCue"...
3. Select all `.swift` files from the `CardOnCue/` directory
4. Ensure "Copy items if needed" is **unchecked** (files are already in place)
5. Click "Add"

### 3. Configure Capabilities

#### Required Capabilities

In Xcode → Target → Signing & Capabilities:

1. **Sign in with Apple**
   - Click "+ Capability"
   - Add "Sign in with Apple"

2. **Background Modes**
   - Click "+ Capability"
   - Add "Background Modes"
   - Enable:
     - ✅ Location updates
     - ✅ Background fetch
     - ✅ Remote notifications (optional, for server-driven push)

3. **Location Services**
   - Handled via Info.plist (see below)

#### Info.plist Configuration

Add these keys to `Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>CardOnCue needs camera access to scan membership cards and barcodes.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>CardOnCue uses your location to automatically show the correct membership card when you arrive at a store.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>CardOnCue monitors your location in the background to automatically suggest cards when you arrive at stores. Your location is never stored or tracked.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>CardOnCue needs location access to monitor when you arrive at stores and automatically show your membership cards. Your location is never stored or tracked.</string>
```

### 4. Configure Signing

1. Select your Development Team in "Signing & Capabilities"
2. Ensure "Automatically manage signing" is enabled
3. Update Bundle Identifier if needed (default: `app.cardoncue.CardOnCue`)

### 5. Build and Run

```bash
# Build from command line
xcodebuild -project CardOnCue.xcodeproj -scheme CardOnCue -sdk iphonesimulator

# Or in Xcode
⌘ + R
```

## Architecture

### Services

#### BarcodeService
Handles barcode scanning and rendering:
- **Scanning**: Uses `AVFoundation` + `Vision` framework
- **Rendering**: Uses `CoreImage` filters (`CIQRCodeGenerator`, `CICode128BarcodeGenerator`)
- **Supported formats**: QR, Code128, PDF417, Aztec, EAN-13, UPC-A

#### LocationService
Manages region monitoring and dynamic refresh:
- **Region monitoring**: Up to 20 `CLCircularRegion` monitored simultaneously
- **Dynamic refresh**: Swaps regions when user moves > 500m
- **Fallback**: Uses `significantLocationChange` and `visit` monitoring

#### StorageService
Encrypted local storage:
- **Encryption**: AES-256-GCM with `CryptoKit`
- **Master key**: Stored in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- **Database**: SQLite with Data Protection Class C
- **Optional sync**: E2E encrypted upload to backend

#### APIClient
HTTP client for backend API:
- **Authentication**: Bearer token (JWT)
- **Endpoints**: Cards CRUD, region refresh, location search
- **Error handling**: Automatic retry with exponential backoff

#### KeychainService
Secure storage for master key and auth tokens:
- **Master key**: Generated on first launch (device-bound)
- **Auth tokens**: Access token (15 min) + refresh token (7 days)
- **Access control**: Keychain items require device unlock

### Models

#### Card
```swift
struct Card: Identifiable, Codable {
    let id: String
    let userId: String
    var name: String
    var barcodeType: BarcodeType
    var payload: String  // Decrypted payload
    var tags: [String]
    var networkIds: [String]
    var validFrom: Date?
    var validTo: Date?
    var oneTime: Bool
    var usedAt: Date?
    var metadata: [String: String]
    let createdAt: Date
    var updatedAt: Date
}
```

#### BarcodeType
```swift
enum BarcodeType: String, Codable {
    case qr
    case code128
    case pdf417
    case aztec
    case ean13
    case upcA = "upc_a"
    case code39
    case itf
}
```

## Usage

### 1. Scan a Card

```swift
// Present scanner
ScannerView { result in
    switch result {
    case .success(let scannedBarcode):
        print("Scanned: \(scannedBarcode.payload)")
        // Save to storage
        await storageService.saveCard(from: scannedBarcode)
    case .failure(let error):
        print("Scan failed: \(error)")
    }
}
```

### 2. Render a Barcode

```swift
// Render crisp barcode image
let renderer = BarcodeRenderer()
let image = try renderer.render(
    payload: "123456789",
    type: .code128,
    size: CGSize(width: 300, height: 150)
)

// Display in SwiftUI
Image(uiImage: image)
    .resizable()
    .aspectRatio(contentMode: .fit)
```

### 3. Monitor Locations

```swift
// Start location monitoring
let locationService = LocationService()
await locationService.startMonitoring()

// Handle region entry
locationService.onRegionEnter = { region in
    print("Entered: \(region.identifier)")
    // Show notification
    await notificationManager.showCardNotification(for: region)
}

// Refresh regions when moved
await locationService.refreshRegions(
    userNetworks: ["costco", "whole-foods"]
)
```

## Testing

### Unit Tests

```bash
# Run tests from command line
xcodebuild test -project CardOnCue.xcodeproj -scheme CardOnCue -destination 'platform=iOS Simulator,name=iPhone 15'

# Or in Xcode
⌘ + U
```

### UI Tests

TODO: Add UI test targets

## Privacy & Security

- ✅ **Local-first**: Cards stored encrypted locally by default
- ✅ **No tracking**: Location never logged or stored persistently
- ✅ **E2E encryption**: If sync enabled, server cannot decrypt payloads
- ✅ **Keychain**: Master key protected by device unlock + Data Protection

See `/docs/privacy-security.md` for full documentation.

## Deployment

### TestFlight

1. Archive build (Xcode → Product → Archive)
2. Distribute to App Store Connect
3. Submit to TestFlight Beta Testing

### App Store

1. Complete App Privacy details (Privacy Nutrition Labels)
2. Submit for App Review
3. Include clear explanation of location usage

## Troubleshooting

### Location Permissions Not Working

Ensure `Info.plist` has all location usage description keys.

### Barcode Rendering Fails

Some barcode types may not be supported by CoreImage on all iOS versions. Falls back to third-party renderer.

### Region Monitoring Not Triggering

- Check that "Always" location permission is granted
- Verify Background Modes are enabled in capabilities
- Test on physical device (simulators have limited location simulation)

## Contributing

See main project README for contribution guidelines.

## License

MIT
