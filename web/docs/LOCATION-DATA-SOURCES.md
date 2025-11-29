# Location Data Sources Integration

## Overview

CardOnCue uses a **multi-source location data strategy** to populate the database with business locations. This document outlines all available data sources, integration status, and setup requirements.

## ✅ Integrated Data Sources

### 1. OpenStreetMap (Overpass API)
**Status:** ✅ Fully Integrated
**Cost:** FREE
**Rate Limit:** ~10,000 queries/day
**Coverage:** Worldwide, community-maintained

**Implemented for:**
- Costco
- Sam's Club
- BJ's Wholesale Club
- Libraries (public)
- Gyms/Fitness Centers (Planet Fitness, LA Fitness, 24 Hour Fitness, Equinox, etc.)
- Generic brand queries

**Code Location:** `lib/data-sources/openstreetmap.ts`

**How it works:**
```typescript
// Example: Import Costco locations
import { findCostcoLocations } from '@/lib/data-sources/openstreetmap';

const locations = await findCostcoLocations(
  34.0522,  // latitude
  -118.2437, // longitude
  50        // radius in km
);

// Returns: Array of locations with address, coordinates, phone, website
```

**Pros:**
- Completely FREE
- No API key required
- Good coverage for major retail chains
- Community-maintained, always improving

**Cons:**
- Data quality varies by region
- Some smaller businesses may be missing
- Depends on community contributions

---

### 2. Google Maps Places API
**Status:** ✅ Skeleton Integrated (Needs API Key)
**Cost:** ~$0.032 per Nearby Search + $0.017 per Place Details
**Rate Limit:** Based on billing
**Coverage:** Worldwide, Google-quality data

**Code Location:** `lib/data-sources/google-places.ts`

**Setup Required:**
1. Get Google Cloud API key with Places API enabled
2. Add to Vercel environment: `GOOGLE_MAPS_API_KEY=your_key_here`
3. System automatically uses as fallback when OpenStreetMap has insufficient data

**How it works:**
```typescript
import { findCostcoLocations } from '@/lib/data-sources/google-places';

const locations = await findCostcoLocations(34.0522, -118.2437, 50);
```

**Intelligent Fallback:**
The system tries OpenStreetMap first (free), then falls back to Google Places only if needed.

**Pros:**
- Highest data quality
- Most comprehensive coverage
- Includes phone numbers, websites, ratings, photos
- Regularly updated by Google

**Cons:**
- Costs money ($0.032-0.05 per location search)
- Requires API key and billing setup
- Rate limits based on billing tier

---

### 3. GPT-5.1 AI Discovery
**Status:** ✅ Already Implemented (see LOCATION-DISCOVERY.md)
**Cost:** ~$0.02-0.05 per discovery request
**Coverage:** Depends on AI knowledge

This is the **last resort fallback** when both OpenStreetMap and Google Places have insufficient data.

---

## 🔧 Unified Import System

**Code Location:** `lib/data-sources/unified-location-import.ts`

The unified import system automatically selects the best data source:

```
┌─────────────────────────────────────────┐
│     Import Request for "Costco"         │
└─────────────────┬───────────────────────┘
                  ↓
        ┌─────────────────────┐
        │ Try OpenStreetMap   │ (FREE)
        └─────────┬───────────┘
                  ↓
          Found 10+ locations?
         ┌────Yes─→ Use OSM data ✅
         No
         ↓
    ┌─────────────────────┐
    │ Try Google Places   │ ($$$)
    └─────────┬───────────┘
              ↓
      Found locations?
     ┌────Yes─→ Use Google data ✅
     No
     ↓
┌─────────────────────┐
│ Use AI Discovery    │ ($$$)
└─────────────────────┘
```

**Usage:**
```typescript
import { importLocationsForBrand } from '@/lib/data-sources/unified-location-import';

const result = await importLocationsForBrand(
  'Costco',           // brand name
  'network_abc123',   // network ID
  34.0522,            // latitude
  -118.2437,          // longitude
  50                  // radius in km
);

console.log(`Imported ${result.count} locations from ${result.source}`);
console.log(`Cost: $${result.costEstimate}`);
```

---

## 🚀 Admin Import Endpoint

**Endpoint:** `POST /api/v1/admin/import-locations`
**Access:** Admin only (nathanfennel@gmail.com)

### Single Brand Import

```bash
curl -X POST https://cardoncue.com/api/v1/admin/import-locations \
  -H "Content-Type: application/json" \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION" \
  -d '{
    "brandName": "Costco",
    "networkId": "net_abc123",
    "latitude": 34.0522,
    "longitude": -118.2437,
    "radiusKm": 50
  }'

# Response:
{
  "success": true,
  "brandName": "Costco",
  "source": "openstreetmap",
  "locationsFound": 12,
  "locationsInserted": 11,
  "costEstimate": 0.00,
  "message": "Imported 11 Costco locations from openstreetmap"
}
```

### Batch Import

```bash
curl -X POST https://cardoncue.com/api/v1/admin/import-locations \
  -H "Content-Type: application/json" \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION" \
  -d '{
    "latitude": 34.0522,
    "longitude": -118.2437,
    "radiusKm": 50,
    "brands": [
      {"name": "Costco", "networkId": "net_costco"},
      {"name": "Sams Club", "networkId": "net_sams"},
      {"name": "BJs Wholesale Club", "networkId": "net_bjs"},
      {"name": "Planet Fitness", "networkId": "net_planet"}
    ]
  }'

# Response:
{
  "success": true,
  "totalBrands": 4,
  "totalLocationsInserted": 47,
  "totalCostEstimate": 0.00,
  "results": [
    {"brandName": "Costco", "source": "openstreetmap", "locationsInserted": 12, "costEstimate": 0},
    {"brandName": "Sams Club", "source": "openstreetmap", "locationsInserted": 15, "costEstimate": 0},
    {"brandName": "BJs Wholesale Club", "source": "google-places", "locationsInserted": 8, "costEstimate": 0.032},
    {"brandName": "Planet Fitness", "source": "openstreetmap", "locationsInserted": 12, "costEstimate": 0}
  ]
}
```

---

## 📊 Supported Brands

### Retail/Warehouse Clubs
| Brand | OSM Support | Google Places | Notes |
|-------|-------------|---------------|-------|
| Costco | ✅ Excellent | ✅ Yes | OSM has great coverage |
| Sam's Club | ✅ Good | ✅ Yes | Part of Walmart |
| BJ's Wholesale Club | ⚠️ Limited | ✅ Yes | Better on Google Places |

### Libraries
| Type | OSM Support | Google Places | Notes |
|------|-------------|---------------|-------|
| Public Libraries | ✅ Excellent | ✅ Yes | OSM amenity=library tag |
| University Libraries | ✅ Good | ✅ Yes | Usually well-mapped |

### Gyms/Fitness
| Brand | OSM Support | Google Places | Notes |
|-------|-------------|---------------|-------|
| Planet Fitness | ✅ Good | ✅ Yes | Growing OSM coverage |
| LA Fitness | ⚠️ Limited | ✅ Yes | Better on Google |
| 24 Hour Fitness | ⚠️ Limited | ✅ Yes | Better on Google |
| Equinox | ⚠️ Limited | ✅ Yes | Premium gyms less in OSM |
| Local Gyms | ⚠️ Varies | ✅ Yes | Google Places recommended |

---

## 🔒 API Keys & Environment Setup

### Current Setup (No action needed)
- ✅ OpenStreetMap: No key required
- ✅ OpenAI GPT-5.1: `OPENAI_API_KEY` already configured

### Google Maps Setup (Action Required)

**Step 1: Get API Key**
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create new project: "CardOnCue Location Services"
3. Enable these APIs:
   - Places API (New)
   - Places API
   - Geocoding API (optional, for address validation)
4. Create credentials → API Key
5. Restrict API key:
   - **Application restrictions:** HTTP referrers (websites)
   - **API restrictions:** Places API, Geocoding API
6. Copy the API key

**Step 2: Add to Vercel**
```bash
# In Vercel dashboard or CLI:
vercel env add GOOGLE_MAPS_API_KEY

# Value: your-google-maps-api-key-here
# Environment: Production, Preview, Development
```

**Step 3: Set up billing**
- Google Places API requires billing enabled
- First $200/month is free (Google Cloud free tier)
- After free tier: ~$0.032 per Nearby Search

**Step 4: Test**
```bash
# After adding key, test the import:
curl -X POST https://cardoncue.com/api/v1/admin/import-locations \
  -H "Content-Type: application/json" \
  -d '{
    "brandName": "Costco",
    "networkId": "net_test",
    "latitude": 34.0522,
    "longitude": -118.2437
  }'

# Should show "google-places" as source for some brands
```

---

## 💡 Data Source Strategy

### When to use each source:

**OpenStreetMap (Always try first)**
- ✅ Major retail chains (Costco, Sam's, Target, Walmart)
- ✅ Public libraries
- ✅ Popular gym chains
- ✅ Large franchise networks
- ✅ Any brand with strong community mapping

**Google Places (Fallback)**
- ✅ Smaller local businesses
- ✅ Premium/boutique gyms
- ✅ Regional chains not in OSM
- ✅ Newly opened locations
- ✅ When OSM returns < 3 results

**AI Discovery (Last resort)**
- ✅ Obscure brands
- ✅ International chains with US expansion
- ✅ Very new businesses
- ✅ When both OSM and Google fail

---

## 📈 Cost Optimization

### Current Cost per Import (50km radius):

| Data Source | Cost/Search | Expected Usage | Monthly Cost |
|-------------|-------------|----------------|--------------|
| OpenStreetMap | $0.00 | 90% of searches | $0.00 |
| Google Places | $0.032 | 8% of searches | ~$2.40 |
| GPT-5.1 AI | $0.05 | 2% of searches | ~$1.00 |
| **Total** | | | **~$3.40/month** |

Assuming 100 brand location imports per month.

### Cost Reduction Tips:
1. **Increase radius** - One 100km search is cheaper than two 50km searches
2. **Batch imports** - Import multiple brands in same region together
3. **Cache aggressively** - Location data rarely changes (30-day cache)
4. **Prioritize OSM** - Always try OpenStreetMap first
5. **Smart thresholds** - Only use Google if OSM returns < 3 results

---

## 🔍 Data Quality Comparison

| Metric | OpenStreetMap | Google Places | AI Discovery |
|--------|---------------|---------------|--------------|
| Accuracy | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Coverage | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| Freshness | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Phone/Website | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| Cost | ⭐⭐⭐⭐⭐ FREE | ⭐⭐⭐ | ⭐⭐⭐ |

---

## 🚦 Next Steps

### Immediate Actions:
1. ✅ **Test OpenStreetMap imports** - Already working, free!
   ```bash
   # Test Costco import in LA
   POST /api/v1/admin/import-locations
   { "brandName": "Costco", "networkId": "...", "latitude": 34.0522, "longitude": -118.2437 }
   ```

2. ⏳ **Set up Google Maps API** (Optional, for better coverage)
   - Follow "Google Maps Setup" section above
   - Enables 8-10% better location coverage
   - Costs ~$2-3/month for typical usage

3. ✅ **AI Discovery already works** - No action needed
   - Automatic fallback when other sources fail
   - Uses existing OPENAI_API_KEY

### Recommended Import Workflow:

```typescript
// 1. Import major brands using OpenStreetMap (FREE)
const majorBrands = [
  { name: 'Costco', networkId: 'net_costco' },
  { name: 'Sams Club', networkId: 'net_sams' },
  { name: 'Planet Fitness', networkId: 'net_planet' },
  // ... add more
];

await batchImportBrands(majorBrands, userLat, userLon, 100);

// 2. For brands with insufficient OSM data, Google Places kicks in automatically
// 3. For rare brands, AI discovery happens automatically

// All automatic! Just call the import endpoint.
```

---

## 📝 Implementation Checklist

### Completed ✅
- [x] OpenStreetMap integration
- [x] Google Places API skeleton
- [x] Unified import system with intelligent fallback
- [x] Admin import endpoint
- [x] Cost tracking
- [x] Duplicate prevention
- [x] Batch import support
- [x] Brand-specific optimizations

### Todo (Optional) ⏳
- [ ] Add GOOGLE_MAPS_API_KEY to Vercel environment
- [ ] Enable Google Cloud billing
- [ ] Test Google Places fallback
- [ ] Monitor import costs in logs
- [ ] Set up automated imports for top 50 brands
- [ ] Create import schedule (weekly updates)

---

## 💬 Support

For questions or issues:
- Email: nathanfennel@gmail.com
- Check logs in Vercel dashboard
- Review import results in database:
  ```sql
  SELECT network_id, COUNT(*) as location_count,
         metadata->>'source' as data_source
  FROM locations
  GROUP BY network_id, metadata->>'source'
  ORDER BY location_count DESC;
  ```

---

## 📚 Related Documentation

- `LOCATION-DISCOVERY.md` - AI-powered location discovery (existing)
- `AI-OPTIMIZATION.md` - AI cost optimization strategies
- `QUICK-START-AI-CACHE.md` - Caching system for reducing API costs

All location imports are cached to minimize costs!
