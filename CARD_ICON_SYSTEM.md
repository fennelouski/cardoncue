# Card Icon Customization System

Complete implementation of card icon customization with intelligent default detection and user-uploadable custom icons.

## Overview

This system allows users to:
1. View automatically-generated brand icons for their cards (Costco, Amazon, etc.)
2. Upload custom icons for any card
3. Reset custom icons back to the default

## Components Built

### Backend (Next.js + Vercel)

#### Database Schema
- **Location**: `web/db/migrations/008_card_icons.sql`
- **Tables Modified**: `cards`
- **New Columns**:
  - `default_icon_url` - Auto-generated icon URL
  - `custom_icon_url` - User-uploaded icon URL
  - `icon_blob_id` - Vercel Blob storage ID

#### Migration Script
- **Location**: `web/scripts/migrate-card-icons.ts`
- **Usage**: `npx tsx scripts/migrate-card-icons.ts`

#### Icon Service
- **Location**: `web/lib/services/iconService.ts`
- **Features**:
  - Intelligent icon detection using Clearbit and Google Favicons
  - Icon caching with Vercel KV (30-day TTL)
  - Automatic fallback to placeholder icons
  - Card name normalization for better matching

#### API Endpoints

All endpoints are in `web/app/api/v1/cards/[cardId]/icon/route.ts`:

1. **GET** `/api/v1/cards/[cardId]/icon`
   - Returns the current icon URL for a card
   - Returns custom icon if set, otherwise default icon

2. **POST** `/api/v1/cards/[cardId]/icon`
   - Upload a custom icon image
   - Accepts: `multipart/form-data` with `icon` field
   - Validates: File type (images only), size (max 5MB)
   - Stores in Vercel Blob storage

3. **DELETE** `/api/v1/cards/[cardId]/icon`
   - Removes custom icon
   - Reverts to default icon
   - Cleans up Vercel Blob storage

### iOS App

#### Data Model
- **Location**: `ios/Shared/Models/Card.swift`
- **Changes**:
  - Added `defaultIconUrl: String?`
  - Added `customIconUrl: String?`
  - Added computed property `iconUrl` (returns custom or default)
  - Added CodingKeys for snake_case conversion

#### Services
- **Location**: `ios/CardOnCue/Services/CardIconService.swift`
- **Methods**:
  - `getCardIcon(cardId:)` - Fetch icon URL
  - `uploadCustomIcon(cardId:image:)` - Upload custom icon
  - `deleteCustomIcon(cardId:)` - Reset to default

#### Views

1. **CardIconView** - Display icon component
   - **Location**: `ios/CardOnCue/Views/CardIconView.swift`
   - Async image loading
   - Placeholder while loading
   - Fallback icon if load fails
   - Configurable size

2. **CardIconPickerView** - Icon selection UI
   - **Location**: `ios/CardOnCue/Views/CardIconPickerView.swift`
   - PhotosPicker integration
   - Upload progress indicator
   - Reset to default option
   - Error handling

## Setup Instructions

### 1. Run Database Migration

```bash
cd web
npx tsx scripts/migrate-card-icons.ts
```

### 2. Configure Environment Variables

Ensure these are set in Vercel:
- `POSTGRES_URL` - Database connection (already set)
- `KV_URL` - Vercel KV for caching (already set)
- `BLOB_READ_WRITE_TOKEN` - Vercel Blob storage (will be auto-created)

### 3. Deploy Backend

```bash
cd web
npm run deploy
```

### 4. Build iOS App

The iOS changes are already in place. Just rebuild the app.

## Usage

### For Users

1. **View Default Icons**: Icons are automatically generated based on card names
2. **Upload Custom Icon**: Tap on a card → Icon settings → Choose from Photos
3. **Reset Icon**: Icon settings → Reset to Default Icon

### For Developers

#### Display a card icon:
```swift
CardIconView(card: myCard, size: 48)
```

#### Open icon picker:
```swift
.sheet(isPresented: $showingIconPicker) {
    CardIconPickerView(card: myCard) { updatedCard in
        // Handle the updated card
        self.myCard = updatedCard
    }
}
```

#### Fetch icon programmatically:
```swift
let iconUrl = try await CardIconService.shared.getCardIcon(cardId: cardId)
```

## How It Works

### Icon Detection Flow

1. User creates a card with name "Costco Membership"
2. System normalizes name → "costco"
3. Tries Clearbit logo API: `https://logo.clearbit.com/costco.com`
4. Falls back to Google Favicon if Clearbit fails
5. Caches result in Vercel KV for 30 days
6. Stores URL in `default_icon_url` column

### Custom Icon Flow

1. User selects image from Photos
2. iOS uploads as JPEG (80% quality)
3. Backend validates and stores in Vercel Blob
4. URL saved to `custom_icon_url` column
5. `custom_icon_url` takes precedence over `default_icon_url`

### Reset Flow

1. User requests reset
2. Backend deletes from Vercel Blob
3. Clears `custom_icon_url` in database
4. Default icon becomes active again

## Testing

### Test Icon Detection
```bash
# Create a test card and check if icon is generated
curl https://www.cardoncue.com/api/v1/cards/[cardId]/icon
```

### Test Upload
```bash
# Upload an icon
curl -X POST \
  -F "icon=@test-icon.jpg" \
  https://www.cardoncue.com/api/v1/cards/[cardId]/icon
```

### Test Reset
```bash
# Reset to default
curl -X DELETE \
  https://www.cardoncue.com/api/v1/cards/[cardId]/icon
```

## Performance Optimizations

1. **Caching**: Icons cached in Vercel KV for 30 days
2. **CDN**: Vercel Blob provides global CDN
3. **Lazy Loading**: iOS loads icons asynchronously
4. **Image Optimization**: JPEG compression at 80% quality

## Future Enhancements

Potential improvements:
- [ ] Icon library with pre-made brand icons
- [ ] AI-powered icon generation
- [ ] Icon color customization
- [ ] Multiple icon variants (light/dark mode)
- [ ] Animated icons support
- [ ] Icon search/browse UI

## Files Created/Modified

### Created
- `web/db/migrations/008_card_icons.sql`
- `web/scripts/migrate-card-icons.ts`
- `web/lib/services/iconService.ts`
- `web/app/api/v1/cards/[cardId]/icon/route.ts`
- `ios/CardOnCue/Services/CardIconService.swift`
- `ios/CardOnCue/Views/CardIconView.swift`
- `ios/CardOnCue/Views/CardIconPickerView.swift`

### Modified
- `ios/Shared/Models/Card.swift`
- `web/package.json` (added @vercel/blob)
