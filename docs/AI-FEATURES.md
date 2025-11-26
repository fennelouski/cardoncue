# AI Features Documentation

## Overview

CardOnCue now includes AI-powered features using OpenAI's GPT-4o-mini and Vision API for intelligent card scanning and categorization.

## Access Control

AI features are available to:
- Premium subscribers
- Admin users (nathanfennel@gmail.com)

## Features

### 1. AI-Powered OCR (`/api/v1/ai/ocr`)

Extract text, barcode information, and metadata from card images.

**Endpoint:** `POST /api/v1/ai/ocr`

**Request Body:**
```json
{
  "imageUrl": "https://example.com/card.jpg",
  // OR
  "imageData": "data:image/jpeg;base64,/9j/4AAQ..."
}
```

**Response:**
```json
{
  "success": true,
  "cardInfo": {
    "text": "COSTCO WHOLESALE\nMember: John Doe\nCard #: 1234 5678 9012 3456",
    "cardName": "Costco Membership",
    "memberName": "John Doe",
    "memberId": "1234567890123456",
    "barcode": {
      "type": "CODE_128",
      "value": "1234567890123456",
      "format": "numeric"
    },
    "confidence": {
      "overall": 0.95,
      "cardName": 0.98,
      "barcode": 0.99
    },
    "suggestedCategory": "membership",
    "colors": {
      "primary": "#E31837",
      "secondary": "#FFFFFF"
    }
  },
  "processingTime": 1250,
  "provider": "openai-vision"
}
```

**Use Cases:**
- Scan membership cards with phone camera
- Extract card details automatically
- Identify barcode types and numbers
- Suggest card categories
- Extract brand colors for UI matching

### 2. AI-Enhanced Categorization (`/api/v1/ai/categorize`)

Intelligently categorize cards using pattern matching and AI when needed.

**Endpoint:** `POST /api/v1/ai/categorize`

**Request Body:**
```json
{
  "cardName": "LA Fitness Membership",
  "cardNumber": "1234567890123",
  "description": "Gym membership card",
  "useAI": true  // Optional, defaults to true
}
```

**Response:**
```json
{
  "success": true,
  "category": "gym",
  "barcodeType": "CODE_128",
  "networkMatches": [
    {
      "id": "net_123",
      "name": "LA Fitness",
      "category": "gym",
      "logoUrl": "https://...",
      "matchScore": 95
    }
  ],
  "confidence": 0.85,
  "suggestions": {
    "cardType": "gym",
    "network": {
      "id": "net_123",
      "name": "LA Fitness"
    },
    "barcodeFormat": "CODE_128",
    "tags": ["gym", "fitness", "membership"],
    "organizationType": "fitness center",
    "reasoning": "Card name contains 'fitness' indicating a gym membership"
  },
  "aiEnhanced": true
}
```

**Categories:**
- `membership` - Retail memberships (Costco, Sam's Club, etc.)
- `loyalty` - Loyalty/rewards programs
- `library` - Library cards
- `gym` - Fitness center memberships
- `transit` - Public transportation cards
- `insurance` - Insurance cards
- `identification` - ID cards
- `gift` - Gift cards
- `credit` - Credit/debit cards
- `parking` - Parking permits
- `access` - Access cards/badges
- `other` - Uncategorized

**How It Works:**
1. First attempts pattern matching using keywords
2. Searches network database for matching organizations
3. If pattern matching yields "other" or no network matches, uses AI for enhanced categorization
4. AI provides reasoning, organization type, and refined tags

## Integration Examples

### iOS Swift Example

```swift
import Foundation

class AIService {
    static let shared = AIService()
    private let apiClient = APIClient.shared

    // Scan card image
    func scanCard(imageData: Data) async throws -> OCRResult {
        let base64 = imageData.base64EncodedString()
        let body = ["imageData": "data:image/jpeg;base64,\(base64)"]

        let response: [String: Any] = try await apiClient.post(
            endpoint: "/api/v1/ai/ocr",
            body: body
        )

        return try OCRResult(from: response)
    }

    // Categorize card
    func categorizeCard(name: String, description: String?) async throws -> CategoryResult {
        var body: [String: Any] = ["cardName": name]
        if let desc = description {
            body["description"] = desc
        }

        let response: [String: Any] = try await apiClient.post(
            endpoint: "/api/v1/ai/categorize",
            body: body
        )

        return try CategoryResult(from: response)
    }
}
```

### Web/React Example

```typescript
// Scan card from file input
async function scanCard(file: File) {
  const base64 = await fileToBase64(file);

  const response = await fetch('/api/v1/ai/ocr', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ imageData: base64 })
  });

  return await response.json();
}

// Categorize card
async function categorizeCard(cardName: string, description?: string) {
  const response = await fetch('/api/v1/ai/categorize', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      cardName,
      description,
      useAI: true
    })
  });

  return await response.json();
}
```

## Cost Optimization

AI features are only invoked when:
- OCR: Always uses AI (required for vision processing)
- Categorization: Only uses AI when pattern matching yields "other" or finds no network matches

This hybrid approach minimizes API costs while maintaining high accuracy.

## Error Handling

Both endpoints return standard error responses:

```json
{
  "error": "Error message",
  "details": "Additional error details"
}
```

Common errors:
- `401`: User not authenticated
- `403`: Premium subscription required
- `400`: Invalid request (missing imageUrl/imageData or cardName)
- `500`: Server error

## Environment Variables Required

Ensure `OPENAI_API_KEY` is set in Vercel environment variables:
1. Go to Vercel Dashboard → Project Settings → Environment Variables
2. Add `OPENAI_API_KEY` with your OpenAI API key
3. Redeploy the application

## Rate Limits

OpenAI API has rate limits. Monitor usage at: https://platform.openai.com/usage

Typical costs:
- OCR (GPT-4o-mini with vision): ~$0.01-0.03 per image
- Categorization (GPT-4o-mini): ~$0.001 per request

## Testing

Test the endpoints using curl:

```bash
# Note: Requires valid Clerk authentication token
curl -X POST https://cardoncue.com/api/v1/ai/categorize \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"cardName": "Costco Membership"}'
```

## Future Enhancements

Potential improvements:
- Batch processing for multiple cards
- Caching of AI results to reduce costs
- Support for additional languages
- Enhanced barcode format detection
- Logo/brand detection
- Card expiration date extraction
