# Card Image Auto-Cropping and Straightening

## Overview

This document outlines the technical approach for implementing automatic cropping and straightening of card images to create a "golden" processed version while preserving the original image as a fallback option.

## Goals

1. **Auto-detect card boundaries** from photos taken at various angles and distances
2. **Apply perspective correction** to straighten skewed or distorted cards
3. **Crop to card edges** to create a clean, professional-looking image
4. **Preserve originals** so users can choose between processed and original images
5. **Process quickly** - ideally in under 1-2 seconds on-device
6. **Maintain quality** - avoid introducing artifacts or reducing resolution unnecessarily

## Technical Approach

### Platform-Specific Implementations

#### iOS (Primary Capture Point)

**Recommended Frameworks:**

1. **Vision Framework** (Apple's native solution)
   - `VNDetectRectanglesRequest` for card boundary detection
   - Supports real-time rectangle detection in camera feed
   - Highly optimized for iOS devices
   - No external dependencies

2. **Core Image Filters**
   - `CIPerspectiveCorrection` for perspective transformation
   - `CICrop` for final cropping
   - Hardware-accelerated on all iOS devices

**Implementation Strategy:**

```swift
import Vision
import CoreImage

class CardImageProcessor {
    // Step 1: Detect card rectangle
    func detectCard(in image: CIImage) async throws -> VNRectangleObservation {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.5  // Credit cards ~1.6:1
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.2  // At least 20% of image
        request.quadratureTolerance = 15  // Degrees of corner angle tolerance

        let handler = VNImageRequestHandler(ciImage: image)
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw CardProcessingError.noCardDetected
        }

        return observation
    }

    // Step 2: Apply perspective correction
    func straightenCard(image: CIImage, rectangle: VNRectangleObservation) -> CIImage {
        let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection")!
        perspectiveCorrection.setValue(image, forKey: kCIInputImageKey)

        // Convert Vision coordinates to Core Image coordinates
        let topLeft = CIVector(cgPoint: rectangle.topLeft)
        let topRight = CIVector(cgPoint: rectangle.topRight)
        let bottomLeft = CIVector(cgPoint: rectangle.bottomLeft)
        let bottomRight = CIVector(cgPoint: rectangle.bottomRight)

        perspectiveCorrection.setValue(topLeft, forKey: "inputTopLeft")
        perspectiveCorrection.setValue(topRight, forKey: "inputTopRight")
        perspectiveCorrection.setValue(bottomLeft, forKey: "inputBottomLeft")
        perspectiveCorrection.setValue(bottomRight, forKey: "inputBottomRight")

        return perspectiveCorrection.outputImage!
    }

    // Step 3: Enhance and optimize
    func enhanceCard(image: CIImage) -> CIImage {
        // Optional enhancements
        let autoEnhance = image.autoAdjustmentFilters()
        var enhanced = image

        for filter in autoEnhance {
            filter.setValue(enhanced, forKey: kCIInputImageKey)
            if let output = filter.outputImage {
                enhanced = output
            }
        }

        return enhanced
    }

    // Full pipeline
    func processCardImage(original: UIImage) async throws -> ProcessedCardImage {
        let ciImage = CIImage(image: original)!

        // Detect card
        let rectangle = try await detectCard(in: ciImage)

        // Apply corrections
        let straightened = straightenCard(image: ciImage, rectangle: rectangle)
        let enhanced = enhanceCard(image: straightened)

        // Convert back to UIImage
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let cgImage = context.createCGImage(enhanced, from: enhanced.extent)!
        let processedImage = UIImage(cgImage: cgImage)

        return ProcessedCardImage(
            original: original,
            processed: processedImage,
            confidence: rectangle.confidence
        )
    }
}
```

#### Web/Backend (Optional Secondary Processing)

**For server-side or web processing:**

1. **OpenCV.js** (JavaScript port of OpenCV)
   - Robust computer vision library
   - Document scanning capabilities
   - Can run client-side in browser or server-side in Node.js

2. **Sharp** (Node.js image processing)
   - Fast image transformations
   - Good for basic cropping and resizing
   - Limited perspective correction

**Implementation Strategy (Node.js/TypeScript):**

```typescript
import cv from '@techstark/opencv-js';
import sharp from 'sharp';

async function processCardImage(imageBuffer: Buffer): Promise<ProcessedImage> {
    // Load image into OpenCV
    const image = cv.imdecode(new Uint8Array(imageBuffer), cv.IMREAD_COLOR);

    // Convert to grayscale for edge detection
    const gray = new cv.Mat();
    cv.cvtColor(image, gray, cv.COLOR_BGR2GRAY);

    // Apply Gaussian blur to reduce noise
    const blurred = new cv.Mat();
    cv.GaussianBlur(gray, blurred, new cv.Size(5, 5), 0);

    // Canny edge detection
    const edges = new cv.Mat();
    cv.Canny(blurred, edges, 50, 150);

    // Find contours
    const contours = new cv.MatVector();
    const hierarchy = new cv.Mat();
    cv.findContours(edges, contours, hierarchy,
                    cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);

    // Find largest quadrilateral contour
    let maxArea = 0;
    let bestContour: any = null;

    for (let i = 0; i < contours.size(); i++) {
        const contour = contours.get(i);
        const area = cv.contourArea(contour);
        const perimeter = cv.arcLength(contour, true);
        const approx = new cv.Mat();
        cv.approxPolyDP(contour, approx, 0.02 * perimeter, true);

        if (approx.rows === 4 && area > maxArea) {
            maxArea = area;
            bestContour = approx;
        }
    }

    if (!bestContour) {
        throw new Error('No card detected');
    }

    // Get corner points
    const corners = getOrderedCorners(bestContour);

    // Calculate target dimensions
    const targetWidth = 856;  // Standard credit card ratio
    const targetHeight = 540;

    // Perspective transform
    const srcPoints = cv.matFromArray(4, 1, cv.CV_32FC2, [
        corners[0].x, corners[0].y,
        corners[1].x, corners[1].y,
        corners[2].x, corners[2].y,
        corners[3].x, corners[3].y
    ]);

    const dstPoints = cv.matFromArray(4, 1, cv.CV_32FC2, [
        0, 0,
        targetWidth, 0,
        targetWidth, targetHeight,
        0, targetHeight
    ]);

    const transform = cv.getPerspectiveTransform(srcPoints, dstPoints);
    const warped = new cv.Mat();
    cv.warpPerspective(image, warped, transform,
                       new cv.Size(targetWidth, targetHeight));

    // Convert back to buffer
    const processedBuffer = cv.imencode('.jpg', warped);

    // Cleanup
    image.delete();
    gray.delete();
    blurred.delete();
    edges.delete();
    contours.delete();
    hierarchy.delete();
    warped.delete();

    return {
        buffer: Buffer.from(processedBuffer),
        confidence: maxArea / (image.rows * image.cols),
        dimensions: { width: targetWidth, height: targetHeight }
    };
}
```

## Algorithm Details

### 1. Card Detection

**Edge-based detection:**
1. Convert to grayscale
2. Apply Gaussian blur to reduce noise
3. Use Canny edge detection
4. Find contours
5. Filter for quadrilateral shapes with card-like aspect ratios
6. Select largest valid contour

**Color-based detection (alternative):**
1. Detect high-contrast regions
2. Use color clustering to identify card vs background
3. Extract boundaries using watershed algorithm

### 2. Corner Detection and Ordering

**Ordering corners correctly (crucial for perspective transform):**
- Top-left: Smallest sum of coordinates (x + y)
- Bottom-right: Largest sum of coordinates
- Top-right: Smallest difference (y - x)
- Bottom-left: Largest difference

```typescript
function orderCorners(points: Point[]): [Point, Point, Point, Point] {
    const sorted = points.sort((a, b) => (a.x + a.y) - (b.x + b.y));
    const topLeft = sorted[0];
    const bottomRight = sorted[3];

    const remaining = [sorted[1], sorted[2]];
    const [topRight, bottomLeft] = remaining.sort((a, b) =>
        (a.y - a.x) - (b.y - b.x)
    );

    return [topLeft, topRight, bottomRight, bottomLeft];
}
```

### 3. Perspective Transformation

**Homography matrix calculation:**
- Maps 4 source points to 4 destination points
- Preserves straight lines
- Corrects for camera angle and distance

**Target aspect ratio considerations:**
- Standard credit card: 85.6mm × 53.98mm (≈1.586:1)
- Gift cards: Often same as credit cards
- Membership cards: Variable, but typically 2:1 to 3:2

**Adaptive sizing:**
```typescript
function calculateTargetDimensions(
    corners: Point[],
    maxDimension = 1200
): { width: number, height: number } {
    const topWidth = distance(corners[0], corners[1]);
    const bottomWidth = distance(corners[2], corners[3]);
    const leftHeight = distance(corners[0], corners[3]);
    const rightHeight = distance(corners[1], corners[2]);

    const avgWidth = (topWidth + bottomWidth) / 2;
    const avgHeight = (leftHeight + rightHeight) / 2;
    const aspectRatio = avgWidth / avgHeight;

    // Scale to fit within maxDimension while preserving aspect ratio
    if (avgWidth > avgHeight) {
        return {
            width: maxDimension,
            height: Math.round(maxDimension / aspectRatio)
        };
    } else {
        return {
            width: Math.round(maxDimension * aspectRatio),
            height: maxDimension
        };
    }
}
```

### 4. Image Enhancement (Optional)

**Post-processing improvements:**

1. **Adaptive histogram equalization**
   - Improves contrast locally
   - Makes text more readable

2. **White balance correction**
   - Normalize colors under different lighting
   - Especially useful for indoor/outdoor photos

3. **Unsharp masking**
   - Subtle sharpening to enhance text
   - Careful not to over-sharpen

4. **Noise reduction**
   - Bilateral filtering preserves edges
   - Reduces JPEG artifacts from original photo

## Data Model Changes

### Database Schema

```sql
-- Add columns to cards table
ALTER TABLE cards ADD COLUMN original_image_url TEXT;
ALTER TABLE cards ADD COLUMN processed_image_url TEXT;
ALTER TABLE cards ADD COLUMN processing_confidence REAL;
ALTER TABLE cards ADD COLUMN use_processed_image BOOLEAN DEFAULT true;
ALTER TABLE cards ADD COLUMN processing_metadata JSONB;

-- Example processing_metadata structure:
{
    "algorithm_version": "1.0",
    "detection_confidence": 0.95,
    "corners_detected": [[x1, y1], [x2, y2], [x3, y3], [x4, y4]],
    "processing_time_ms": 850,
    "enhancements_applied": ["perspective_correction", "auto_contrast"],
    "original_dimensions": { "width": 3024, "height": 4032 },
    "processed_dimensions": { "width": 856, "height": 540 }
}
```

### API Updates

```typescript
// POST /api/v1/cards - Enhanced upload endpoint
interface CreateCardRequest {
    // ... existing fields
    process_image?: boolean;  // Default: true
    save_original?: boolean;  // Default: true
}

interface CreateCardResponse {
    // ... existing fields
    images: {
        original_url: string;
        processed_url: string | null;
        processing_confidence: number | null;
        processing_error?: string;
    };
}

// PATCH /api/v1/cards/:id/image-preference
interface UpdateImagePreferenceRequest {
    use_processed_image: boolean;
}
```

### Swift Model Updates

```swift
struct Card: Identifiable, Codable {
    let id: String
    // ... existing fields

    var originalImageURL: URL?
    var processedImageURL: URL?
    var processingConfidence: Double?
    var useProcessedImage: Bool
    var processingMetadata: ProcessingMetadata?

    // Computed property for display
    var displayImageURL: URL? {
        if useProcessedImage, let processed = processedImageURL {
            return processed
        }
        return originalImageURL
    }
}

struct ProcessingMetadata: Codable {
    let algorithmVersion: String
    let detectionConfidence: Double
    let cornersDetected: [[Double]]
    let processingTimeMs: Int
    let enhancementsApplied: [String]
    let originalDimensions: ImageDimensions
    let processedDimensions: ImageDimensions
}
```

## User Experience Flow

### 1. Card Capture (iOS App)

```
1. User opens camera to scan card
2. Real-time rectangle detection overlay shown
3. When card detected with high confidence:
   - Visual feedback (green outline)
   - Auto-capture or manual capture button
4. After capture:
   - Show loading indicator "Processing image..."
   - Run auto-crop and straighten (1-2 seconds)
5. Present preview with both versions:
   - Primary: Processed image
   - Toggle button: "Show original" / "Show processed"
6. User can accept, retake, or choose version
7. Upload selected version(s) to backend
```

### 2. Card Editing (Post-Upload)

```
1. User views card detail
2. Tap on card image
3. If both versions exist:
   - Show comparison view
   - Swipe or toggle between versions
   - "Use this version" button
4. Selection updates preference in database
```

### 3. Fallback Scenarios

**When processing fails or confidence is low:**

1. **Silent fallback**: Use original image without notification
2. **Optional retry**: "We couldn't auto-straighten your card. Try again?"
3. **Manual mode**: Provide corner-dragging interface for manual adjustment

## Performance Considerations

### On-Device Processing (iOS)

**Optimization techniques:**

1. **Downsample for detection**
   - Detect on lower resolution (e.g., 1024px wide)
   - Apply transform to full resolution
   - Saves 50-70% processing time

2. **Async processing**
   - Use Swift async/await
   - Don't block UI thread
   - Show progress indicator

3. **Memory management**
   - Release intermediate CIImage objects
   - Use autoreleasepool for batch processing
   - Monitor memory warnings

4. **Battery efficiency**
   - Only process when user confirms capture
   - Avoid continuous processing in preview mode
   - Use Metal acceleration when available

### Backend Processing (Optional)

**When to process server-side:**

1. User uploads from photo library (no live detection)
2. iOS processing failed or user's device is too old
3. Web-based upload
4. Batch reprocessing of existing cards

**Cost considerations:**

- CPU time: ~2-3 seconds per image on standard instance
- Memory: ~200-300MB per concurrent process
- Storage: 2x storage (original + processed)

**Optimization:**

```typescript
// Use image processing queue
import Queue from 'bull';

const imageProcessingQueue = new Queue('image-processing', {
    redis: process.env.REDIS_URL
});

imageProcessingQueue.process(async (job) => {
    const { cardId, imageUrl } = job.data;

    try {
        // Download original
        const response = await fetch(imageUrl);
        const buffer = await response.arrayBuffer();

        // Process
        const processed = await processCardImage(Buffer.from(buffer));

        // Upload processed version
        const processedUrl = await uploadToStorage(processed.buffer);

        // Update database
        await updateCard(cardId, {
            processed_image_url: processedUrl,
            processing_confidence: processed.confidence
        });

        return { success: true, processedUrl };
    } catch (error) {
        // Log error but don't fail - original image still exists
        console.error('Image processing failed:', error);
        return { success: false, error: error.message };
    }
});
```

## Quality Assurance

### Success Metrics

1. **Detection accuracy**: >95% for cards on contrasting backgrounds
2. **Processing time**: <2 seconds on device, <5 seconds server-side
3. **User preference**: >80% of users keep processed version
4. **Edge cases handled**:
   - Low light conditions
   - Shiny/reflective cards
   - Transparent/translucent cards
   - Embossed or textured surfaces
   - Cards with complex backgrounds

### Testing Scenarios

**Test image dataset:**

1. ✓ Standard credit card on flat surface
2. ✓ Gift card at 45° angle
3. ✓ Card on patterned background
4. ✓ Card partially obscured
5. ✓ Very shiny/reflective card (light glare)
6. ✓ Card in low light
7. ✓ Card with rounded corners
8. ✓ Card with non-standard aspect ratio
9. ✓ Multiple cards in frame
10. ✓ Card with transparent elements

### Confidence Thresholds

```typescript
enum ProcessingConfidence {
    HIGH = 0.9,      // Auto-use processed version
    MEDIUM = 0.7,    // Show both, default to processed
    LOW = 0.5,       // Show both, default to original
    FAILED = 0.0     // Use original only
}
```

## Future Enhancements

### Phase 2 Features

1. **OCR Integration**
   - After straightening, run OCR to extract card number, expiry
   - Pre-fill form fields automatically
   - Higher accuracy with straightened images

2. **Background Removal**
   - Detect and remove background
   - Add solid color or transparent background
   - Consistent look across all cards

3. **Smart Cropping**
   - Detect and center important elements (logo, number)
   - Maintain consistent padding
   - Generate thumbnail versions

4. **Glare Removal**
   - Detect and remove reflections from shiny cards
   - Inpaint missing areas using ML
   - Preserve underlying text

5. **3D Card Detection**
   - Handle embossed cards better
   - Preserve texture while straightening
   - Use depth information if available

### Machine Learning Approach

**For more advanced detection:**

1. **Custom trained model**
   - Train on dataset of card images
   - Better handling of edge cases
   - Faster inference than traditional CV

2. **Potential frameworks**
   - Create ML for iOS
   - TensorFlow Lite
   - Core ML with custom model

3. **Training data requirements**
   - 10,000+ labeled card images
   - Diverse backgrounds, lighting, angles
   - Annotations for corners and card type

## Implementation Priority

### MVP (Phase 1)

1. iOS: Vision Framework card detection
2. iOS: Core Image perspective correction
3. Store both original and processed images
4. Simple toggle in card detail view
5. Server-side fallback using OpenCV

### Polish (Phase 2)

1. Real-time detection preview in camera
2. Manual corner adjustment interface
3. Confidence-based auto-selection
4. Image enhancement filters
5. Background removal

### Advanced (Phase 3)

1. ML-based detection model
2. OCR integration
3. Glare and reflection removal
4. Batch reprocessing of existing cards
5. A/B testing for optimal parameters

## Security and Privacy

### Considerations

1. **Original image retention**
   - Keep original for legal/verification purposes
   - User can delete processed version
   - Both subject to same access controls

2. **Processing metadata**
   - Don't store sensitive info in metadata
   - Algorithm version for reproducibility
   - Confidence scores for quality monitoring

3. **EXIF data handling**
   - Strip GPS location from uploaded images
   - Preserve orientation information
   - Remove camera model/timestamp if sensitive

4. **Storage optimization**
   - Compress processed images appropriately
   - Use modern formats (WebP, HEIF) when supported
   - Implement lazy loading for thumbnails

## References

### iOS Resources

- [Vision Framework - Detecting Objects in Still Images](https://developer.apple.com/documentation/vision/detecting_objects_in_still_images)
- [Core Image Filter Reference - CIPerspectiveCorrection](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html)
- [AVFoundation - Real-time Rectangle Detection](https://developer.apple.com/documentation/avfoundation)

### OpenCV Resources

- [OpenCV Document Scanner Tutorial](https://docs.opencv.org/4.x/d7/d4d/tutorial_py_thresholding.html)
- [Perspective Transformation](https://docs.opencv.org/4.x/da/d6e/tutorial_py_geometric_transformations.html)
- [Contour Detection](https://docs.opencv.org/4.x/d4/d73/tutorial_py_contours_begin.html)

### Example Projects

- [WeScan](https://github.com/WeTransfer/WeScan) - Document scanning for iOS
- [OpenCV.js Document Scanner](https://github.com/zakaton/opencv-document-scanner)
- [iOS Document Camera](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller)

## Questions for Product/Design

1. Should we show processing progress or make it instant (with slight delay)?
2. What should happen if processing fails - notify user or silently use original?
3. Should we reprocess all existing card images in database?
4. What's the preferred default - processed or original?
5. Do we need admin tools to review processing quality/confidence?
6. Should users be able to manually adjust corners if auto-detection is imperfect?
