# Barcode Scanner Feature Documentation

## Overview

The **Barcode Scanner** is a fully functional camera-based barcode scanning system that allows users to quickly add membership and loyalty cards by scanning their barcodes. The feature includes educational permission prompts, real-time barcode detection, and a review flow for saving scanned cards.

## Architecture

The scanner feature consists of four main components:

### 1. CameraPermissionManager
**File:** `CardOnCue/CameraPermissionManager.swift`

**Purpose:** Centralized state management for camera permissions

**Features:**
- Tracks camera permission status (notDetermined, granted, denied, restricted)
- Provides methods to check and request permissions
- Observable object that updates UI when permission status changes

**Permission States:**
- `.notDetermined` - User hasn't been asked yet
- `.granted` - User has allowed camera access
- `.denied` - User has explicitly denied access
- `.restricted` - Camera access restricted by device policies

### 2. CameraPermissionPromptView
**File:** `CardOnCue/CameraPermissionPromptView.swift`

**Purpose:** Educational prompt explaining why camera access is needed

**Features:**
- Friendly, non-technical explanation
- List of benefits (quick scanning, privacy, speed)
- "Allow Camera Access" button
- "Enter Manually Instead" fallback option
- Cancel button to dismiss

**Benefits Highlighted:**
- Quickly scan any barcode type
- Your photos are never saved
- Faster than manual entry

**User Flow:**
1. User taps "Allow Camera Access"
2. System permission dialog appears
3. If granted → Shows scanner
4. If denied → Dismisses and scanner button is hidden

### 3. BarcodeScannerView
**File:** `CardOnCue/BarcodeScannerView.swift`

**Purpose:** Real-time camera preview and barcode detection

**Features:**
- Live camera preview with AVFoundation
- Real-time barcode detection for multiple formats
- Visual scanning frame with animated corners
- Flash toggle (if device supports)
- "Enter Manually" fallback button
- Success animation on scan
- Haptic feedback

**Supported Barcode Types:**
- QR Code
- Code 128
- PDF417
- Aztec
- EAN-13
- UPC-E (mapped to UPC-A)
- Code 39
- ITF-14 (mapped to ITF)

**UI Elements:**
```
┌─────────────────────────────┐
│  [Cancel]      Scan Card     │ ← Navigation
├─────────────────────────────┤
│                              │
│     [Camera Preview]         │
│                              │
│  Position barcode within     │
│         frame                │
│                              │
│     ┌─────────────┐         │
│     │   [Frame]   │         │ ← Scanning frame
│     └─────────────┘         │
│                              │
│         [⚡ Flash]           │ ← Flash toggle
│                              │
│     [Enter Manually]         │ ← Fallback
│                              │
└─────────────────────────────┘
```

**Technical Implementation:**
- Uses `AVCaptureSession` for video capture
- Uses `AVCaptureMetadataOutput` for barcode detection
- Runs on background queue for performance
- Main thread updates for UI changes
- Automatic flash control via torch mode

### 4. ScannedCardReviewView
**File:** `CardOnCue/ScannedCardReviewView.swift`

**Purpose:** Review and save scanned barcode with additional details

**Features:**
- Shows scanned barcode number and type
- Success indicator (green checkmark)
- Form to add card name (required)
- Optional expiry date
- Optional one-time use flag
- Optional tags
- "Save Card" button
- "Scan Again" option
- Encryption before saving

**Form Fields:**
- **Card Name** (required) - Display name for the card
- **Has Expiry Date** (toggle) - Shows date picker when enabled
- **One-Time Use** (toggle) - For gift cards/vouchers
- **Tags** (optional) - Comma-separated categories

## User Flow

### First-Time Scanner Use (Permission Not Determined)

1. User taps "Scan Card" button
2. `CameraPermissionPromptView` appears with educational message
3. User taps "Allow Camera Access"
4. iOS system dialog appears
5. **If Granted:**
   - Permission prompt dismisses
   - Scanner opens immediately
   - Camera starts capturing
6. **If Denied:**
   - Permission prompt dismisses
   - Scanner button hidden in future sessions
   - Only "Add Manually" button shown

### Scanning Flow (Permission Already Granted)

1. User taps "Scan Card" button
2. `BarcodeScannerView` opens immediately
3. Camera preview appears
4. User positions barcode in frame
5. Barcode detected automatically:
   - Success animation (green overlay)
   - Haptic feedback (success vibration)
   - Scanner pauses
6. `ScannedCardReviewView` appears
7. User enters card name and optional details
8. User taps "Save Card"
9. Card encrypted and saved
10. Views dismiss, card appears in list

### Scanning with Camera Denied

- "Scan Card" button doesn't appear in menu
- Empty state only shows "Add Manually" button
- User must use manual entry

## Permission Flow Logic

### CardListView Integration

**File:** `CardOnCue/CardListView.swift`

The `CardListView` manages the entire permission flow:

```swift
@StateObject private var cameraPermission = CameraPermissionManager()
@State private var showingScanner = false
@State private var showingPermissionPrompt = false

private func handleScanRequest() {
    switch cameraPermission.permissionStatus {
    case .granted:
        showingScanner = true
    case .notDetermined:
        showingPermissionPrompt = true
    case .denied, .restricted:
        // Do nothing, button should be hidden
        break
    }
}
```

### EmptyStateView Integration

**File:** `CardOnCue/EmptyStateView.swift`

The empty state conditionally shows buttons based on permission:

```swift
var canScan: Bool = true

// In button section:
if canScan {
    // Show both scan and manual entry buttons
} else {
    // Only show manual entry button (styled as primary)
}
```

## Security & Privacy

### Camera Access
- Photos are **never saved** to device storage
- Only the barcode data is captured and encrypted
- Camera session stops immediately after scan
- No continuous recording or photo capture

### Data Encryption
After scanning, the barcode data is:
1. Encrypted using AES-256-GCM
2. Stored with a 256-bit key in iOS Keychain
3. Synced to iCloud in encrypted form
4. Never transmitted unencrypted

### Privacy Description
**Info.plist:** `NSCameraUsageDescription`
```
CardOnCue needs access to your camera to scan barcodes on your
membership and loyalty cards. Your photos are never saved.
```

## Error Handling

### Camera Not Available
- App checks `AVCaptureDevice.default()` availability
- Gracefully handles missing camera (simulators)
- Shows appropriate error message

### Permission Denied After Initial Grant
- Rare scenario (user can revoke in Settings)
- Scanner fails to start
- User should be directed to Settings

### Barcode Detection Failures
- Scanner continues running
- User can try different angles/lighting
- Fallback: "Enter Manually" button always available

### Unsupported Barcode Types
- Scanner detects and maps to closest supported type
- User can correct type in review screen if needed

## Testing Checklist

### Permission Flow
- [ ] First launch shows educational prompt
- [ ] Granting permission opens scanner
- [ ] Denying permission hides scan button
- [ ] Scan button doesn't appear when denied
- [ ] Manual entry always available

### Scanner Functionality
- [ ] Camera preview appears correctly
- [ ] QR codes detected successfully
- [ ] Barcodes (Code 128, EAN-13, etc.) detected
- [ ] Flash toggle works (on physical device)
- [ ] Success animation plays on detection
- [ ] Haptic feedback occurs on detection
- [ ] Scanner stops after successful scan

### Review & Save
- [ ] Scanned data appears correctly
- [ ] Barcode type detected correctly
- [ ] Card name validation works
- [ ] Optional fields can be added
- [ ] Save encrypts and stores correctly
- [ ] Card appears in list after save
- [ ] "Scan Again" returns to scanner

### Edge Cases
- [ ] Works in low light (with flash)
- [ ] Handles damaged/partial barcodes gracefully
- [ ] Handles very long barcode numbers
- [ ] Works with cards at various angles
- [ ] Multiple barcodes on card (scans first detected)

## Performance Considerations

### Battery Optimization
- Camera session runs only when scanner is visible
- Session stops immediately after successful scan
- Background processing on dedicated queue
- Torch/flash turned off when scanner dismissed

### Memory Management
- Video frames not retained
- Metadata objects processed and released
- Preview layer properly deallocated
- Weak references prevent retain cycles

### Responsiveness
- Barcode detection happens in real-time (<100ms)
- UI updates on main thread
- Camera initialization on background queue
- No blocking operations on main thread

## Future Enhancements

Possible improvements for future versions:

1. **Multi-Barcode Scanning:** Detect multiple barcodes in one session
2. **Barcode History:** Remember recently scanned codes
3. **Manual Focus:** Allow user to tap to focus
4. **Zoom Control:** Pinch to zoom for small barcodes
5. **Brightness Adjustment:** Auto-adjust for better detection
6. **Card Detection:** Automatically detect card edges
7. **Batch Scanning:** Scan multiple cards in sequence
8. **Scan Analytics:** Track success rates per barcode type
9. **Alternative Scanner Libraries:** MLKit or Vision framework
10. **AR Guides:** Visual guides for optimal card positioning

## Accessibility

- VoiceOver support for all buttons
- High contrast scanning frame
- Haptic feedback for blind users
- Clear audio cues for success/failure
- Large touch targets for controls
- No reliance on color alone

## Code References

### Main Files
- Scanner View: `CardOnCue/BarcodeScannerView.swift`
- Permission Prompt: `CardOnCue/CameraPermissionPromptView.swift`
- Review View: `CardOnCue/ScannedCardReviewView.swift`
- Permission Manager: `CardOnCue/CameraPermissionManager.swift`

### Integration Points
- Card List: `CardOnCue/CardListView.swift:99-109` (handleScanRequest)
- Empty State: `CardOnCue/EmptyStateView.swift:97-133` (conditional buttons)
- Info.plist: `CardOnCue/Info.plist:7-8` (camera description)

### Dependencies
- AVFoundation: Camera capture and barcode detection
- SwiftUI: User interface
- SwiftData: Card storage
- Combine: State management
- CryptoKit: Barcode data encryption

## Known Limitations

1. **Simulator:** Camera not available, testing requires physical device
2. **iPod Touch:** Models without rear camera cannot use scanner
3. **Privacy Settings:** Users must have camera enabled in Settings
4. **Barcode Quality:** Damaged barcodes may not scan reliably
5. **Lighting:** Very low light may require flash (drains battery)

## Troubleshooting

### Scanner Won't Open
- Check camera permission in Settings > CardOnCue
- Verify `NSCameraUsageDescription` in Info.plist
- Ensure device has rear camera
- Restart app and try again

### Barcodes Not Detecting
- Improve lighting (use flash toggle)
- Hold card steady and flat
- Try different distances from camera
- Clean camera lens
- Fallback: Use "Enter Manually"

### Permission Already Denied
- User must go to Settings > CardOnCue > Camera
- Toggle permission on
- Return to app
- Scan button should reappear after app restarts
