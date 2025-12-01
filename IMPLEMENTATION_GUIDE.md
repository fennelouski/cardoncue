# Card Image Editing Implementation Guide

## Completed Components

### 1. Data Models (`ios/Shared/Models/CardImage.swift`)
- ✅ `BarcodeRepresentation` enum - Manages digital vs. image preference
- ✅ `ImageEditingMetadata` - Stores crop, rotation, contrast, brightness, perspective
- ✅ `BarcodeImageData` - Barcode image with metadata and quality score
- ✅ `CardFrontImage` - Front card photo with editing data
- ✅ `BarcodeQualityMetrics` - Quality scores (readability, sharpness, contrast)

### 2. Card Model Updates (`ios/Shared/Models/Card.swift`)
- ✅ Added `barcodeImageData`, `frontCardImage`, `barcodeRepresentationPreference`, `barcodeQualityMetrics`
- ✅ Added computed properties: `effectiveBarcodeRepresentation`, `shouldUseScannedBarcode`, `displayIconUrl`
- ✅ Updated CodingKeys for proper serialization

### 3. Services
- ✅ **ImageStorageService** (`ios/CardOnCue/Services/ImageStorageService.swift`)
  - Local file management in Documents directory
  - Save/load/delete images
  - Apply editing metadata (crop, rotate, contrast, brightness, perspective correction)

- ✅ **BarcodeQualityService** (`ios/CardOnCue/Services/BarcodeQualityService.swift`)
  - Automatic barcode detection using Vision framework
  - Sharpness evaluation
  - Contrast evaluation
  - Quality suggestions
  - Recommendation engine for digital vs. image barcode

### 4. Views
- ✅ **CameraCaptureView** (`ios/CardOnCue/Views/CameraCaptureView.swift`)
  - Camera/photo library integration
  - Separate modes for barcode and front card images

- ✅ **ImageEditingView** (`ios/CardOnCue/Views/ImageEditingView.swift`)
  - Rotation slider
  - Contrast adjustment
  - Brightness adjustment
  - Real-time quality evaluation
  - Quality suggestions sheet
  - Reset functionality

- ✅ **PerspectiveCorrectionView** (`ios/CardOnCue/Views/PerspectiveCorrectionView.swift`)
  - Interactive corner dragging
  - Visual overlay for straightening
  - Apply perspective correction

## Integration Steps (To Be Completed)

### Step 1: Update CardDetailView

Add these state variables to `CardDetailView`:
```swift
@State private var showingBarcodeImageCapture = false
@State private var showingFrontCardCapture = false
@State private var showingImageEditor = false
@State private var capturedImage: UIImage?
@EnvironmentObject var storageService: StorageService
```

Replace the `barcodeSection` with:
```swift
private var barcodeSection: some View {
    VStack(spacing: 12) {
        HStack {
            Text("Barcode")
                .font(.headline)

            Spacer()

            // Representation picker
            if card.barcodeImageData != nil {
                Picker("", selection: $card.barcodeRepresentationPreference) {
                    Text("Digital").tag(BarcodeRepresentation.digital)
                    Text("Image").tag(BarcodeRepresentation.scannedImage)
                    Text("Auto").tag(BarcodeRepresentation.automatic)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }

        // Display barcode (digital or image based on preference)
        ZStack {
            Rectangle()
                .fill(Color.white)
                .cornerRadius(8)

            if card.shouldUseScannedBarcode,
               let barcodeData = card.barcodeImageData,
               let image = try? ImageStorageService.shared.loadImage(from: barcodeData.localFilePath) {
                // Show edited barcode image
                let finalImage = barcodeData.editingMetadata != nil ?
                    ImageStorageService.shared.applyEditingMetadata(image, metadata: barcodeData.editingMetadata!) : image
                Image(uiImage: finalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
                    .brightness(brightness - 1.0)
            } else if let image = generateBarcode() {
                // Show digital barcode
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
                    .brightness(brightness - 1.0)
            }
        }
        .frame(height: 200)

        // Add/Edit barcode image button
        Button(action: {
            showingBarcodeImageCapture = true
        }) {
            HStack {
                Image(systemName: card.barcodeImageData != nil ? "photo.badge.plus" : "camera")
                Text(card.barcodeImageData != nil ? "Edit Barcode Image" : "Add Barcode Image")
            }
            .font(.subheadline)
            .foregroundColor(.appPrimary)
        }

        // Brightness slider (existing code)
        VStack(spacing: 8) {
            // ... existing brightness slider code ...
        }
    }
}
```

Add these sheet modifiers to the main body:
```swift
.sheet(isPresented: $showingBarcodeImageCapture) {
    CameraCaptureView(mode: .barcodeImage) { image in
        capturedImage = image
        showingImageEditor = true
    }
}
.sheet(isPresented: $showingImageEditor) {
    if let image = capturedImage {
        ImageEditingView(image: image, card: card) { editedImage, metadata in
            Task {
                await saveBarcodeImage(editedImage, metadata: metadata)
            }
        }
    }
}
```

Add this helper method:
```swift
private func saveBarcodeImage(_ image: UIImage, metadata: ImageEditingMetadata) async {
    do {
        let filePath = try ImageStorageService.shared.saveBarcodeImage(image, cardId: card.id)
        let metrics = await BarcodeQualityService.shared.evaluateImage(image, expectedBarcodeType: card.barcodeType)

        var updatedCard = card
        updatedCard.barcodeImageData = BarcodeImageData(
            localFilePath: filePath,
            editingMetadata: metadata,
            qualityScore: metrics.overallScore
        )
        updatedCard.barcodeQualityMetrics = metrics

        storageService.updateCard(updatedCard)
    } catch {
        errorMessage = "Failed to save barcode image: \(error.localizedDescription)"
        showError = true
    }
}
```

### Step 2: Update CardIconView

Read `ios/CardOnCue/Views/CardIconView.swift` and add support for displaying front card images:

```swift
// In CardIconView body, check for frontCardImage first:
var body: some View {
    if let frontImage = card.frontCardImage,
       let image = try? ImageStorageService.shared.loadImage(from: frontImage.localFilePath) {
        // Display front card image
        let finalImage = frontImage.editingMetadata != nil ?
            ImageStorageService.shared.applyEditingMetadata(image, metadata: frontImage.editingMetadata!) : image
        Image(uiImage: finalImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
    } else {
        // Existing icon logic
        // ... existing code ...
    }
}
```

### Step 3: Add Front Card Image Capture to CardIconPickerView

Update `CardIconPickerView` to include an option to capture a front card image:

```swift
// Add a button for front card image capture
Button(action: {
    showingFrontCardCapture = true
}) {
    HStack {
        Image(systemName: "camera")
        Text("Take Card Photo")
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color.appPrimary.opacity(0.1))
    .cornerRadius(8)
}
```

## Testing Checklist

### Barcode Detection & Extraction
- [ ] Scan a QR code and verify automatic type/payload detection
- [ ] Scan a Code 128 barcode and verify detection
- [ ] Scan an image with multiple barcodes and verify selection UI
- [ ] Test detection with poor quality image (low confidence handling)
- [ ] Test "no barcode detected" flow
- [ ] Verify confidence scores are accurate

### Image Editing & Quality
- [ ] Capture a barcode image using the camera
- [ ] Edit the image (crop, rotate, adjust contrast/brightness)
- [ ] Apply perspective correction to straighten the image
- [ ] View quality metrics and suggestions
- [ ] Switch between digital and scanned barcode representations
- [ ] Set preference to "Automatic" and verify it chooses the best one

### Front Card Images
- [ ] Capture a front card image
- [ ] Verify front card image displays as the card icon
- [ ] Edit front card image (crop, straighten, etc.)

### Persistence & Cleanup
- [ ] Verify images persist across app restarts
- [ ] Test image deletion and cleanup
- [ ] Verify metadata is properly saved/loaded

## NEW: Automatic Barcode Detection & Extraction

The app now supports **fully automatic barcode reading** from images using iOS Vision framework:

### Features
- **Automatic Type Detection**: Scans image and automatically determines barcode type (QR, Code128, PDF417, Aztec, EAN-13, UPC-A, Code39, ITF)
- **Payload Extraction**: Extracts the actual barcode data/numbers from the image
- **Confidence Scoring**: Provides confidence score for each detected barcode
- **Multiple Barcode Support**: Detects all barcodes in an image, sorted by confidence
- **Quality Evaluation**: Combines detection with image quality metrics
- **Smart Thresholding**: Only recommends scanned barcodes if they're 90%+ quality AND 95%+ readable
- **Automatic Cropping**: Crops to barcode area for maximum size on lock screen

### BarcodeQualityService.swift New Methods

```swift
// Detect all barcodes in an image
let barcodes = await BarcodeQualityService.shared.detectBarcodes(in: image)
// Returns: [DetectedBarcodeData]

// Detect only the best (highest confidence) barcode
let bestBarcode = await BarcodeQualityService.shared.detectBestBarcode(in: image)
// Returns: DetectedBarcodeData?
```

### DetectedBarcodeData Structure

```swift
struct DetectedBarcodeData {
    let barcodeType: BarcodeType    // Automatically detected type
    let payload: String              // Extracted barcode data
    let confidence: Double           // Detection confidence (0.0 - 1.0)
    let detectedSymbology: String   // Raw Vision framework symbology
    let boundingBox: CGRect          // Location of barcode in image (normalized 0-1)
}
```

### BarcodeImageData Structure

```swift
struct BarcodeImageData {
    let localFilePath: String
    var editingMetadata: ImageEditingMetadata?
    var qualityScore: Double?
    let capturedAt: Date
    var barcodeBoundingBox: CGRect?  // For automatic cropping to barcode area
}
```

### BarcodeDetectionView

A new view (`BarcodeDetectionView.swift`) provides a complete UI for barcode detection:
- Shows all detected barcodes with type, payload, and confidence
- Allows users to select which barcode to use (if multiple detected)
- Displays quality indicators (high/medium/low confidence)
- Handles "no barcode detected" case gracefully

### Usage Example

```swift
// In your card creation flow:
CameraCaptureView(mode: .barcodeImage) { capturedImage in
    // Show barcode detection
    showBarcodeDetection = true
}
.sheet(isPresented: $showBarcodeDetection) {
    BarcodeDetectionView(image: capturedImage) { detectedBarcode in
        // User selected a barcode
        let newCard = Card(
            userId: currentUserId,
            name: "My Card",
            barcodeType: detectedBarcode.barcodeType,  // Auto-detected!
            payload: detectedBarcode.payload,           // Auto-extracted!
            cardType: .other
        )
        storageService.addCard(newCard)
    }
}
```

### Supported Barcode Types

Vision framework automatically detects:
- QR Code
- Code 128
- PDF417
- Aztec Code
- EAN-13
- UPC-A
- Code 39
- ITF (Interleaved 2 of 5)

### Lock Screen Barcode Cropping

New methods in `ImageStorageService` for lock screen display:

```swift
// Crop image to just the barcode area with margin
let croppedImage = ImageStorageService.shared.cropToBarcode(
    image,
    normalizedBoundingBox: detectedBarcode.boundingBox,
    margin: 0.15  // 15% margin around barcode
)

// Convenience method: load, apply edits, and crop for lock screen
let lockScreenImage = try ImageStorageService.shared.loadBarcodeImageForLockScreen(
    from: card.barcodeImageData
)
```

This ensures the barcode fills as much of the lock screen widget as possible for optimal scanability.

## Key Features

1. **Dual Barcode Support**: Users can use either digital (generated) or scanned barcodes
2. **Automatic Selection**: Quality metrics automatically recommend the best representation
3. **Full Editing Suite**: Crop, rotate, contrast, brightness, and perspective correction
4. **Quality Feedback**: Real-time quality evaluation with improvement suggestions
5. **Front Card Images**: Custom photos for easy card identification
6. **Local Storage**: All images stored securely on device
7. **Automatic Barcode Detection**: Scan cards and automatically extract barcode type and data

## Architecture Notes

### Storage
- Images stored in Documents/CardImages, Documents/BarcodeImages, Documents/FrontCardImages
- File paths stored in Card model (not image data itself, for efficiency)
- All image operations are non-destructive (original + metadata)

### Vision Framework Integration
- **Barcode Detection**: VNDetectBarcodesRequest automatically detects barcode type and extracts payload
- **Quality Evaluation**: Vision framework assesses barcode readability with confidence scores
- **Supported Types**: QR, Code128, PDF417, Aztec, EAN-13, UPC-A, Code39, ITF
- **Symbology Conversion**: Automatic mapping from Vision framework types to app BarcodeType enum

### Image Processing
- **Core Image Filters**: Used for sharpness, contrast, brightness adjustments
- **Perspective Correction**: Applied using Core Image CIPerspectiveCorrection filter
- **Quality Metrics**: Combines Vision barcode detection + sharpness + contrast scores
- **Automatic Recommendation**: Compares digital vs scanned quality (90% overall + 95% readability threshold)
- **Barcode Cropping**: Automatically crops to barcode area with 15% margin for lock screen display
- **Bounding Box Tracking**: Stores barcode location for precise cropping

### User Flow
1. User captures card image via camera
2. BarcodeQualityService automatically detects all barcodes in image
3. User selects desired barcode (if multiple detected)
4. Card created with auto-detected type and payload
5. User can optionally edit/enhance the image
6. Quality metrics determine if image or digital barcode should be primary
7. User retains control with manual override options
