# Import Queue Guide - 105 Brands Ready for OpenStreetMap

## 📋 What's in the Queue?

I've created a comprehensive queue of **105 brands/networks** that commonly have membership or loyalty cards, organized by priority:

### Category Breakdown:

| Category | Count | Examples |
|----------|-------|----------|
| **Warehouse Clubs** | 3 | Costco, Sam's Club, BJ's |
| **Gyms & Fitness** | 30 | Planet Fitness, LA Fitness, 24 Hour Fitness, Equinox |
| **Grocery Stores** | 25 | Kroger, Safeway, Whole Foods, Trader Joe's, H-E-B |
| **Pharmacies** | 5 | CVS, Walgreens, Rite Aid |
| **Retail Stores** | 15 | Target, Best Buy, REI, PetSmart, Barnes & Noble |
| **Coffee Shops** | 5 | Starbucks, Dunkin', Peet's Coffee |
| **Fast Food** | 10 | Panera, Chipotle, McDonald's, Chick-fil-A |
| **Gas Stations** | 8 | Shell, BP, Chevron, 7-Eleven |
| **Movie Theaters** | 5 | AMC, Regal, Cinemark, Alamo Drafthouse |
| **TOTAL** | **105** | |

## 🚀 How to Import

### Method 1: Batch Import for a City (Recommended)

Import all 105 brands for a specific geographic area (e.g., Los Angeles):

```bash
# Create the network records first
cd web
npx tsx scripts/import-queue.ts

# This will:
# 1. Create network records for all 105 brands
# 2. Generate network IDs
# 3. Save updated queue with network IDs

# Then import locations for your city
curl -X POST https://cardoncue.com/api/v1/admin/import-locations \
  -H "Content-Type: application/json" \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION" \
  -d '{
    "latitude": 34.0522,
    "longitude": -118.2437,
    "radiusKm": 100,
    "brands": [
      {"name": "Costco", "networkId": "net_xxx"},
      {"name": "Sams Club", "networkId": "net_yyy"},
      ...
    ]
  }'
```

### Method 2: Import Top 10 Brands First

Start with the most common membership cards:

```bash
curl -X POST https://cardoncue.com/api/v1/admin/import-locations \
  -H "Content-Type: application/json" \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION" \
  -d '{
    "latitude": 34.0522,
    "longitude": -118.2437,
    "radiusKm": 50,
    "brands": [
      {"name": "Costco", "networkId": "TBD"},
      {"name": "Sams Club", "networkId": "TBD"},
      {"name": "BJs Wholesale Club", "networkId": "TBD"},
      {"name": "Planet Fitness", "networkId": "TBD"},
      {"name": "LA Fitness", "networkId": "TBD"},
      {"name": "Kroger", "networkId": "TBD"},
      {"name": "CVS Pharmacy", "networkId": "TBD"},
      {"name": "Target", "networkId": "TBD"},
      {"name": "Starbucks", "networkId": "TBD"},
      {"name": "AMC Theatres", "networkId": "TBD"}
    ]
  }'
```

### Method 3: Import by Category

Import all gyms first, then groceries, etc:

```javascript
// In web directory
const { importLocationsForBrand } = require('./lib/data-sources/unified-location-import');

// Import all gyms in LA
const gyms = [
  'Planet Fitness',
  'LA Fitness',
  '24 Hour Fitness',
  'Anytime Fitness',
  'Crunch Fitness',
  'Equinox',
  "Gold's Gym",
  'Lifetime Fitness',
  'YMCA'
];

for (const gym of gyms) {
  await importLocationsForBrand(
    gym,
    networkId, // Get from database
    34.0522,   // LA latitude
    -118.2437, // LA longitude
    50         // 50km radius
  );

  // Wait 2 seconds between requests (be nice to OpenStreetMap)
  await new Promise(r => setTimeout(r, 2000));
}
```

## 📊 Expected Results

Based on OpenStreetMap coverage, here's what you can expect:

### Excellent Coverage (80%+ of locations):
- ✅ Costco
- ✅ Sam's Club
- ✅ Major grocery chains (Kroger, Safeway, Whole Foods)
- ✅ CVS, Walgreens
- ✅ Target
- ✅ Starbucks
- ✅ McDonald's, Subway
- ✅ Shell, BP, Chevron

### Good Coverage (50-80%):
- ⚠️ Planet Fitness
- ⚠️ LA Fitness
- ⚠️ BJ's Wholesale Club
- ⚠️ REI
- ⚠️ AMC Theatres

### Limited Coverage (< 50%):
- ⚠️ Boutique gyms (SoulCycle, Barry's, etc.)
- ⚠️ Regional chains
- ⚠️ Smaller coffee shops

For brands with limited OSM coverage, the system will automatically fall back to Google Places API (if configured) or GPT-5.1 AI discovery.

## 💰 Cost Estimate

**Using OpenStreetMap Only (FREE):**
- 105 brands × $0.00 = **$0.00**
- Estimated time: ~3-4 hours for 105 brands (with 2-second delays)
- Expected total locations: ~15,000-25,000 locations nationwide

**With Google Places Fallback:**
- 80 brands via OSM × $0.00 = $0.00
- 25 brands via Google × $0.032 = $0.80
- **Total: ~$0.80** (one-time import)

## ⏱️ Import Strategy

### Recommended Approach:

**Phase 1: High-Priority Brands (10 brands)**
Import the most common membership cards first:
- Warehouse clubs (3)
- Top gyms (3)
- Top grocery stores (2)
- CVS/Walgreens (2)

**Phase 2: Popular Brands (40 brands)**
- Remaining gyms
- Major grocery chains
- Retail stores (Target, Best Buy, etc.)
- Starbucks & major coffee

**Phase 3: Long Tail (55 brands)**
- Regional grocery stores
- Gas stations
- Fast food chains
- Movie theaters
- Boutique fitness

### Geographic Strategy:

**Option A: Major Cities First**
Import all 105 brands for major metro areas:
1. New York (40M people in metro)
2. Los Angeles (18M)
3. Chicago (10M)
4. Houston (7M)
5. Phoenix (5M)

**Option B: Nationwide Coverage**
Import all brands with large radius from central points:
- East Coast: NYC (radius: 300km)
- West Coast: LA (radius: 300km)
- Midwest: Chicago (radius: 300km)
- South: Houston (radius: 300km)
- Southwest: Phoenix (radius: 300km)

This covers ~70-80% of US population.

## 🔍 Verifying Imports

After importing, check the results:

```sql
-- View import statistics
SELECT
  n.name as network_name,
  COUNT(l.id) as location_count,
  l.metadata->>'source' as data_source
FROM networks n
LEFT JOIN locations l ON n.id = l.network_id
WHERE n.name IN ('Costco', 'Sam''s Club', 'Planet Fitness')
GROUP BY n.name, l.metadata->>'source'
ORDER BY location_count DESC;

-- Example output:
-- network_name    | location_count | data_source
-- Costco          | 572           | openstreetmap
-- Sam's Club      | 598           | openstreetmap
-- Planet Fitness  | 1,847         | openstreetmap
```

## 📝 Queue File Location

**Static JSON:** `web/scripts/import-queue.json`

This file contains:
- All 105 brands
- Priority ordering
- Category tags
- Ready to use with import API

## 🎯 Success Metrics

Track these metrics after importing:

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Brands Imported | 105 | `SELECT COUNT(DISTINCT network_id) FROM locations` |
| Total Locations | 20,000+ | `SELECT COUNT(*) FROM locations` |
| Coverage (% with locations) | 90%+ | Brands with >5 locations / 105 |
| Data Source Mix | 90% OSM, 10% Google | Count by metadata->>'source' |
| Cost | < $5 | Sum of costEstimate from imports |

## 🚦 Rate Limiting

Be respectful to OpenStreetMap's servers:

- ✅ **Recommended:** 2-3 seconds between requests
- ⚠️ **Maximum:** 1 request per second
- ❌ **Don't:** Parallel requests to Overpass API

The import system automatically adds delays.

## 💡 Tips & Tricks

**1. Start Small**
Import 5-10 brands for your local area first to test the system.

**2. Check Coverage First**
Before importing, check if OpenStreetMap has good coverage:
- Visit https://overpass-turbo.eu/
- Run query for your brand and area
- If results look good, proceed with import

**3. Use Batch Import**
Import multiple brands in one API call to reduce overhead.

**4. Monitor Logs**
Watch Vercel logs during imports:
```bash
vercel logs --follow
```

**5. Cache is Your Friend**
All imports are automatically cached for 30 days, so re-running the same import is free!

## 🐛 Troubleshooting

**No locations found for a brand?**
- Brand might not be in OpenStreetMap
- Try different brand name variations
- Enable Google Places API as fallback
- Last resort: Use GPT-5.1 AI discovery

**Import taking too long?**
- Reduce radius (try 25km instead of 100km)
- Import fewer brands at once
- Check Overpass API status: https://overpass-api.de/api/status

**Database errors?**
- Ensure network records exist first (run import-queue.ts)
- Check Vercel Postgres connection
- Verify user permissions in database

## 📚 Related Docs

- `LOCATION-DATA-SOURCES.md` - Full data source documentation
- `scripts/import-queue.ts` - Queue generation script
- `scripts/import-queue.json` - Ready-to-use brand list

## ✅ Quick Start Checklist

- [ ] Review the 105 brand list
- [ ] Decide on import strategy (phase or geographic)
- [ ] Run `npx tsx scripts/import-queue.ts` to create networks
- [ ] Start with Phase 1 (top 10 brands)
- [ ] Monitor import results in database
- [ ] Expand to Phase 2 and 3
- [ ] Set up Google Places API for better coverage (optional)

---

**Ready to import? Start with the top 10 brands for your area and expand from there!**
