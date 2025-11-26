# AI Location Discovery Feature

## Overview

CardOnCue now automatically discovers and adds locations for newly created cards using GPT-5.1 AI. This feature ensures users always have nearby locations for their cards, even if they're not in our database yet.

## How It Works

### Automatic Flow (Card Creation)

When a user creates a new card:

1. **Check for Nearby Locations**: System checks if there are any locations within **30km** of the user for the card's networks
2. **Skip if Locations Exist**: If locations are found within 30km, no AI discovery is triggered
3. **AI Discovery**: If NO locations are found within 30km:
   - Uses GPT-5.1 to search for and structure location data
   - Discovers up to 10 physical locations per network
   - Validates coordinates and address information
   - Inserts verified locations into the database
4. **Background Process**: Discovery runs asynchronously without blocking card creation

### Required Request Data

When creating a card with location discovery, include:

```json
POST /api/v1/cards
{
  "name": "LA Fitness Membership",
  "barcode_type": "CODE_128",
  "payload_encrypted": "...",
  "network_ids": ["net_123", "net_456"],

  // Required for location discovery
  "user_location": {
    "latitude": 34.0522,
    "longitude": -118.2437
  },

  // Optional but recommended
  "user_address": {
    "city": "Los Angeles",
    "state": "California"
  }
}
```

### Manual Discovery Endpoint

You can also manually trigger location discovery:

```
POST /api/v1/ai/discover-locations
{
  "cardId": "card_abc123",
  "networkIds": ["net_123"],
  "userLocation": {
    "latitude": 34.0522,
    "longitude": -118.2437
  },
  "userAddress": {
    "city": "Los Angeles",
    "state": "California"
  }
}
```

**Response:**

```json
{
  "success": true,
  "skipped": false,
  "discovered": 8,
  "inserted": 7,
  "networks": [
    {
      "networkId": "net_123",
      "networkName": "LA Fitness",
      "locationCount": 7
    }
  ]
}
```

If locations already exist within 30km:

```json
{
  "success": true,
  "skipped": true,
  "reason": "Locations already exist within 30km",
  "discovered": 0,
  "inserted": 0,
  "networks": []
}
```

## AI Technology

### Model: GPT-5.1

Using OpenAI's latest GPT-5.1 model for location discovery because:
- Superior reasoning capabilities for understanding business locations
- Better at structuring location data consistently
- More accurate geographic coordinate extraction
- Enhanced understanding of business types and categories

### Location Data Extracted

For each location, the AI extracts:
- **Name**: Official business/branch name
- **Address**: Complete street address
- **City, State, Country**: Geographic location
- **Postal Code**: ZIP/postal code
- **Latitude & Longitude**: Precise GPS coordinates
- **Phone**: Contact number (when available)
- **Website**: Official website (when available)

### Data Validation

Before inserting into the database, locations are validated:
- All required fields present (name, address, city, state, coordinates)
- Latitude: -90 to 90
- Longitude: -180 to 180
- Duplicate check: Won't insert if location already exists

## Use Cases

### 1. Library Cards

**Scenario**: User adds "San Francisco Public Library" card

- System checks for SFPL locations within 30km
- If none found, AI discovers all SFPL branch locations
- User can now see all 28 branch locations on their map
- Geofence notifications work for any branch

### 2. Gym Memberships

**Scenario**: User moves to a new city with their national gym membership

- System has no locations in the new city
- AI discovers local branches automatically
- User gets notifications near any discovered location

### 3. Retail Memberships

**Scenario**: User adds "Costco Membership" card

- AI discovers nearby Costco warehouses
- Returns formatted location data including:
  - Store numbers
  - Hours of operation (in metadata)
  - Special services available

## Cost Optimization

### Smart Discovery Triggers

Location discovery is **only triggered** when:
1. Card has associated networks
2. User provides their location
3. **NO locations exist within 30km**

This prevents:
- Duplicate discoveries
- Unnecessary API costs
- Database bloat

### Approximate Costs

Using GPT-5.1 for location discovery:
- **Per network search**: ~$0.02-0.05
- **Per card** (average 1-2 networks): ~$0.03-0.10
- **10 cards per day**: ~$0.30-1.00/day

Much cheaper than manual data entry or commercial location APIs.

## Analytics Tracking

Location discoveries are tracked with the `location_discovery` event:

```sql
INSERT INTO analytics_events (
  user_id,
  event_type,
  card_id,
  metadata
) VALUES (
  'user_123',
  'location_discovery',
  'card_abc',
  {
    "discovered": 8,
    "inserted": 7,
    "networks": [
      {"networkId": "net_123", "networkName": "LA Fitness", "locationCount": 7}
    ]
  }
)
```

## iOS Integration

```swift
// Create card with location discovery
func createCardWithDiscovery(
    name: String,
    barcodeType: String,
    payload: String,
    networkIds: [String]
) async throws -> Card {
    // Get user location
    let location = await LocationService.shared.getCurrentLocation()

    guard let userLat = location?.coordinate.latitude,
          let userLon = location?.coordinate.longitude else {
        throw APIError.locationRequired
    }

    // Get user address (optional but recommended)
    let placemark = await LocationService.shared.getCurrentPlacemark()

    let body: [String: Any] = [
        "name": name,
        "barcode_type": barcodeType,
        "payload_encrypted": payload,
        "network_ids": networkIds,
        "user_location": [
            "latitude": userLat,
            "longitude": userLon
        ],
        "user_address": [
            "city": placemark?.locality ?? "",
            "state": placemark?.administrativeArea ?? ""
        ]
    ]

    let response: [String: Any] = try await apiClient.post(
        endpoint: "/api/v1/cards",
        body: body
    )

    // Location discovery happens in background
    // User will see locations appear within seconds

    return try Card(from: response["card"] as? [String: Any] ?? [:])
}

// Manually trigger discovery for existing card
func discoverLocations(cardId: String) async throws -> LocationDiscoveryResult {
    let location = await LocationService.shared.getCurrentLocation()
    let placemark = await LocationService.shared.getCurrentPlacemark()

    guard let userLat = location?.coordinate.latitude,
          let userLon = location?.coordinate.longitude else {
        throw APIError.locationRequired
    }

    let body: [String: Any] = [
        "cardId": cardId,
        "networkIds": [], // Will be fetched from card
        "userLocation": [
            "latitude": userLat,
            "longitude": userLon
        ],
        "userAddress": [
            "city": placemark?.locality ?? "",
            "state": placemark?.administrativeArea ?? ""
        ]
    ]

    let response: [String: Any] = try await apiClient.post(
        endpoint: "/api/v1/ai/discover-locations",
        body: body
    )

    return try LocationDiscoveryResult(from: response)
}
```

## Database Schema

### Analytics Event

```sql
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL,
  event_type TEXT NOT NULL,  -- 'location_discovery'
  card_id TEXT,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Example Metadata

```json
{
  "discovered": 8,
  "inserted": 7,
  "networks": [
    {
      "networkId": "net_abc123",
      "networkName": "LA Fitness",
      "locationCount": 7
    }
  ]
}
```

## Error Handling

### No Locations Found

If AI cannot find any locations:
- No error is thrown
- Returns `discovered: 0, inserted: 0`
- Logged for monitoring

### Partial Success

If some locations are invalid:
- Valid locations are inserted
- Invalid ones are skipped
- Response shows inserted count

### AI API Failure

If GPT-5.1 API fails:
- Error is logged
- Card creation still succeeds
- User can manually trigger discovery later

## Monitoring

Monitor location discovery in Vercel logs:

```
Card card_abc: No nearby locations found, triggering AI discovery...
Card card_abc: Discovered 8 locations, inserted 7
```

Check for patterns:
- High discovery rate → Good user experience
- Low insertion rate → Data quality issues
- Frequent API errors → OpenAI issues or rate limits

## Future Enhancements

Potential improvements:
1. **Batch Discovery**: Discover locations for multiple cards at once
2. **Caching**: Cache discovered locations for popular networks
3. **User Feedback**: Let users report incorrect locations
4. **Photos**: Extract location photos from Google Places
5. **Hours**: Include business hours in location data
6. **Ratings**: Include business ratings and reviews
