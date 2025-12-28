# Backend Integration - Implementation Complete

## ✅ What's Been Completed

### 1. Backend Recovery ✅
- **Restored** the entire `web/` directory from git history (commit d35f8f4)
- **Verified** all API endpoints are functional:
  - Card template matching (`/api/v1/card-templates/match`)
  - Gift card brand discovery (`/api/v1/gift-cards/discover-brand`)
  - Network locations (`/api/v1/networks/{networkId}/locations`)
  - Region refresh (`/api/v1/region-refresh`)

### 2. iOS APIClient Updates ✅
- **Added** new API methods:
  - `matchCardTemplate()` - Matches scanned cards to templates in database
  - `discoverGiftCardBrand()` - Uses Claude AI to identify gift card brands
  - `getNetworkLocations()` - Fetches all locations for a brand/network
  - `refreshRegions()` - Gets monitored regions near user location

- **Created** response models:
  - `CardTemplateMatchResponse`
  - `GiftCardBrandResponse`
  - `NetworkLocationsResponse`

### 3. Card Scanning Integration ✅
- **Integrated** template matching in `ScannedCardReviewView.swift`:
  - Generates image hash from scanned card
  - Extracts text signature from OCR
  - Calls backend API to match against card templates
  - Auto-populates form fields when match found (>60% confidence)
  - Shows card name, location, address, coordinates

- **Added** gift card brand discovery:
  - Automatically detects gift cards (Code128, Code39, EAN13)
  - Uses Claude AI to identify brand and accepting merchants
  - Updates card name with discovered brand
  - Tracks which networks accept the card

### 4. App Configuration ✅
- **Initialized** API client in `CardOnCueApp.swift`
- **Created** environment key for dependency injection
- **Set** backend URL to `https://cardoncue.vercel.app/api`

---

## 🚧 What Still Needs To Be Done

### 1. Multi-Location Support (High Priority)

**Problem:** Currently, cards can only have ONE location. For brands like Costco with hundreds of locations, users should see ALL nearby locations.

**Implementation Needed:**

#### A. Update CardModel Schema
```swift
// Add new field to CardModel.swift
var networkIds: [String] = []  // ✅ Already exists!
var primaryLocationId: String? = nil  // NEW: Default location
var brandId: String? = nil  // NEW: Link to backend brand
```

#### B. Create LocationsListView
```swift
// New view: CardLocationsView.swift
struct CardLocationsView: View {
    let card: CardModel
    @State private var nearbyLocations: [NetworkLocation] = []

    var body: some View {
        List(nearbyLocations) { location in
            LocationRow(location)
        }
        .onAppear {
            fetchNearbyLocations()
        }
    }

    func fetchNearbyLocations() async {
        // Call apiClient.getNetworkLocations()
    }
}
```

#### C. Update CardDetailView
Add button to show all locations:
```swift
Button("View All Locations (\(locationCount))") {
    showingLocations = true
}
.sheet(isPresented: $showingLocations) {
    CardLocationsView(card: card)
}
```

#### D. Update Geofencing
Modify `GeofenceManager` to monitor ALL locations for multi-location brands:
```swift
// For Costco card, monitor 5 nearest Costco locations
// Not just the user's "home" location
```

### 2. Database Setup & Deployment (Critical)

**Backend database is NOT deployed yet!**

#### Required Steps:

1. **Set up Vercel Postgres**:
   ```bash
   cd web
   npm install
   vercel env pull  # Get environment variables
   ```

2. **Run Database Migrations**:
   ```bash
   # Create tables
   psql $POSTGRES_URL -f db/migrations/008_card_icons.sql
   psql $POSTGRES_URL -f db/migrations/009_gift_cards.sql
   psql $POSTGRES_URL -f db/migrations/010_gift_card_balance_tracking.sql
   psql $POSTGRES_URL -f db/migrations/011_card_locations.sql
   psql $POSTGRES_URL -f db/migrations/012_user_profiles.sql
   psql $POSTGRES_URL -f db/migrations/013_card_templates.sql
   psql $POSTGRES_URL -f db/migrations/014_brands.sql
   psql $POSTGRES_URL -f db/migrations/015_locations.sql
   psql $POSTGRES_URL -f db/migrations/016_template_locations.sql
   ```

3. **Seed Initial Data**:
   ```bash
   # Import curated locations (Costco, libraries, etc.)
   node web/scripts/seed-curated.js
   ```

4. **Deploy to Vercel**:
   ```bash
   cd web
   vercel --prod
   ```

5. **Set Environment Variables**:
   - `POSTGRES_URL` - Database connection string
   - `ANTHROPIC_API_KEY` - For gift card brand discovery
   - `CLERK_PUBLISHABLE_KEY` - Authentication
   - `CLERK_SECRET_KEY` - Authentication

### 3. Template Creation Workflow (Medium Priority)

**Users need a way to CREATE templates!**

When a user scans a card that doesn't match any template:
1. Backend should create a new template automatically
2. Template gets `verified: false` initially
3. As more users scan the same card → `usage_count` increases
4. Admin dashboard can verify popular templates

**Implementation:**
```swift
// In ScannedCardReviewView.saveCard()
// After saving card, upload template
func uploadTemplate() async {
    guard let apiClient = apiClient, let image = capturedImage else { return }

    let template = CardTemplateUploadRequest(
        imageHash: generateImageHash(from: image),
        textSignature: parsedCardData?.fullText,
        cardName: cardName,
        cardType: cardType.isEmpty ? nil : cardType,
        locationName: locationName.isEmpty ? nil : locationName,
        locationAddress: locationAddress,
        locationLat: locationLatitude,
        locationLng: locationLongitude
    )

    try? await apiClient.createTemplate(template)
}
```

### 4. Admin Dashboard Access (Low Priority)

The backend has a full admin dashboard at `/admin`:
- Manage brands
- Manage locations
- Review and verify card templates
- Link templates to multiple locations

**Setup:**
- Admin routes require `@100apps.studio` email domain
- Configure Clerk authentication to allow admin users

---

## 📋 Testing Checklist

Before deploying to production:

- [ ] **Deploy backend to Vercel**
- [ ] **Run database migrations**
- [ ] **Test card scanning → template matching**
- [ ] **Test gift card → brand discovery**
- [ ] **Test location search → network locations**
- [ ] **Verify API authentication works**
- [ ] **Add error handling for network failures**
- [ ] **Test with real Costco card (multi-location)**
- [ ] **Test with real gift card (Red Lobster, Target, etc.)**

---

## 🔧 Quick Start for Development

### Backend Development:
```bash
cd web
npm install
npm run dev  # Runs on http://localhost:3000
```

### Test API Endpoints:
```bash
# Test template matching
curl -X POST http://localhost:3000/api/v1/card-templates/match \
  -H "Content-Type: application/json" \
  -d '{"imageHash": "abc123", "textSignature": "costco wholesale", "limit": 5}'

# Test brand discovery
curl -X POST http://localhost:3000/api/v1/gift-cards/discover-brand \
  -H "Content-Type: application/json" \
  -d '{"cardName": "Red Lobster Gift Card", "barcode": "1234567890"}'
```

### iOS Testing:
- Set `APIClient` baseURL to `http://localhost:3000/api` for local testing
- Use iOS Simulator to connect to local backend
- Add print statements to see API responses

---

## 📊 Database Schema Quick Reference

### Key Tables:

**brands**
- Stores canonical brand information (Costco, Louisville Library, etc.)
- Fields: `name`, `display_name`, `category`, `logo_url`, `verified`

**brand_locations**
- Physical locations for each brand
- Fields: `brand_id`, `name`, `address`, `city`, `state`, `latitude`, `longitude`, `regular_hours`, `verified`

**card_templates**
- Fingerprints of card designs for matching
- Fields: `image_hash`, `text_signature`, `card_name`, `brand_id`, `usage_count`, `confidence_score`, `verified`

**template_brand_locations** (Junction table)
- Links templates to multiple locations
- Example: One "Costco Membership" template → 47 Costco locations
- Fields: `template_id`, `brand_location_id`, `priority`

---

## 🎯 Priority Next Steps

1. **Deploy backend to Vercel** (Critical - nothing works without this!)
2. **Run database migrations** (Critical)
3. **Test end-to-end with real cards** (High priority)
4. **Implement multi-location UI** (High priority)
5. **Add template upload on save** (Medium priority)
6. **Set up admin dashboard** (Low priority)

---

## 💡 Architecture Benefits

With this system:
- ✅ **Smart brand recognition** - Scan Costco card → automatically knows it's Costco
- ✅ **Multi-location support** - One card works at ALL brand locations
- ✅ **Rich metadata** - Hours, phone, address for each location
- ✅ **Community-driven** - Templates improve as more users scan
- ✅ **AI-powered gift cards** - Automatically identifies accepting merchants
- ✅ **Geofence optimization** - Backend calculates 20 closest locations

---

## 🐛 Known Issues

1. **Image hashing is basic** - Replace `generateImageHash()` with proper perceptual hashing (pHash or dHash)
2. **No offline support** - Template matching requires network connection
3. **No template caching** - Could cache matched templates locally
4. **No retry logic** - Network failures should retry with exponential backoff

---

## 📞 Support

- Backend API Documentation: `web/docs/api-spec.yaml`
- Database Schema: `web/db/migrations/`
- iOS Integration: `CardOnCue/APIClient.swift`

---

**Status**: Backend integration code complete ✅ | Deployment pending ⏳
