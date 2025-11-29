# Run First 25 Brands Test

## Quick Start

I've created a comprehensive endpoint that will:
1. ✅ Run database migration (create import_queue table)
2. ✅ Populate queue with all 105 brands
3. ✅ Test endpoints BEFORE processing (verify no data exists)
4. ✅ Process first 25 brands from OpenStreetMap
5. ✅ Verify location data was correctly stored
6. ✅ Test endpoints AFTER processing (verify data is returned)
7. ✅ Show queue statistics

## How to Run

### Method 1: Using curl (Recommended)

1. **Login to https://cardoncue.com** in your browser
2. **Open Browser DevTools** (F12 or Cmd+Option+I)
3. **Go to Application/Storage → Cookies**
4. **Copy the `__session` cookie value** from clerk
5. **Run this command:**

```bash
curl -X POST https://cardoncue.com/api/v1/admin/setup-and-test-queue \
  -H "Cookie: __session=YOUR_SESSION_COOKIE_HERE" \
  -H "Content-Type: application/json" \
  -v
```

### Method 2: Using Browser Console

1. **Login to https://cardoncue.com**
2. **Open DevTools Console** (F12 or Cmd+Option+J)
3. **Paste and run:**

```javascript
fetch('/api/v1/admin/setup-and-test-queue', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' }
})
.then(r => r.json())
.then(data => {
  console.log('✅ Setup Complete!');
  console.log('Results:', data);

  // Pretty print results
  data.results.forEach(step => {
    console.log(`\n${step.success ? '✅' : '❌'} ${step.step}`);
    console.log(`   ${step.message}`);
    if (step.data) console.log('   Data:', step.data);
    if (step.error) console.error('   Error:', step.error);
  });
});
```

## Expected Output

The endpoint will return a detailed JSON response with 7 steps:

```json
{
  "success": true,
  "message": "Setup and test complete: 7/7 steps successful",
  "results": [
    {
      "step": "1. Database Migration",
      "success": true,
      "message": "import_queue table created successfully"
    },
    {
      "step": "2. Queue Population",
      "success": true,
      "message": "Added X new networks, Y existed, Z queue items added",
      "data": {
        "networksCreated": 105,
        "networksExisted": 0,
        "queueItemsAdded": 105
      }
    },
    {
      "step": "3. Pre-Processing Test",
      "success": true,
      "message": "All brands have 0 locations (as expected)",
      "data": [
        {"brand": "Costco", "networkId": "...", "locationCount": 0},
        {"brand": "Sam's Club", "networkId": "...", "locationCount": 0}
      ]
    },
    {
      "step": "4. Process 25 Brands",
      "success": true,
      "message": "Processed 25 brands: 23 succeeded, 2 failed",
      "data": {
        "processResults": [...],
        "successCount": 23,
        "failureCount": 2
      }
    },
    {
      "step": "5. Verify Location Data",
      "success": true,
      "message": "23/25 brands have location data. Total: 15,432 locations",
      "data": {
        "totalLocations": 15432,
        "brandsWithData": 23,
        "verificationResults": [...]
      }
    },
    {
      "step": "6. Post-Processing Endpoint Tests",
      "success": true,
      "message": "2/2 endpoint tests passed",
      "data": {
        "endpointTests": [
          {
            "endpoint": "/api/v1/networks/{id}/locations",
            "test": "Get Costco locations",
            "success": true,
            "resultCount": 572
          }
        ]
      }
    },
    {
      "step": "7. Queue Statistics",
      "success": true,
      "message": "Queue statistics retrieved",
      "data": [
        {"status": "completed", "count": 25},
        {"status": "pending", "count": 80}
      ]
    }
  ],
  "summary": {
    "totalSteps": 7,
    "successfulSteps": 7,
    "failedSteps": 0
  }
}
```

## What Happens During Processing

The endpoint will take **approximately 50-60 seconds** to complete because:
- It processes 25 brands sequentially
- Each brand has a 2-second delay (OpenStreetMap rate limiting)
- Total: 25 brands × 2 seconds = 50 seconds minimum

You'll see console output like:
```
🚀 Starting comprehensive queue setup and test...

STEP 1: Running migration...
✅ Migration complete

STEP 2: Populating queue with 105 brands...
✅ Queue populated: 105 items

STEP 3: Testing endpoints before processing...
✅ Pre-test complete: Clean slate

STEP 4: Processing first 25 brands...
  Processing: Costco...
    ✅ 572 locations from openstreetmap
  Processing: Sam's Club...
    ✅ 598 locations from openstreetmap
  [... 23 more brands ...]
✅ Processing complete: 23/25

STEP 5: Verifying location data...
✅ Verification complete: 15,432 total locations

STEP 6: Testing endpoints after processing...
✅ Endpoint tests complete

STEP 7: Getting queue statistics...
✅ Statistics retrieved

============================================================
✅ COMPLETE: 7/7 steps successful
============================================================
```

## Verifying Results

### Check Queue Status
```bash
curl https://cardoncue.com/api/v1/admin/import-queue?status=completed \
  -H "Cookie: __session=YOUR_SESSION"
```

Should show 25 completed items.

### Check Location Count
```bash
curl "https://cardoncue.com/api/v1/networks/{COSTCO_NETWORK_ID}/locations" \
  -H "Cookie: __session=YOUR_SESSION"
```

Should return Costco locations.

### View Queue Statistics
```bash
curl https://cardoncue.com/api/v1/admin/import-queue \
  -H "Cookie: __session=YOUR_SESSION"
```

## Troubleshooting

### Error: "Unauthorized"
- Make sure you're logged in at cardoncue.com
- Refresh your session cookie
- Cookie must be from cardoncue.com domain

### Error: "Forbidden"
- Endpoint is restricted to nathanfennel@gmail.com
- Verify you're logged in with the correct account

### Error: "Table already exists"
- This is fine! It will skip migration and continue
- The endpoint handles this gracefully

### Some Brands Failed
- This is normal! Not all brands have good OpenStreetMap coverage
- Check the `failureCount` in step 4
- Failed brands will show in the `processResults` array
- Common failures: regional chains, boutique gyms

### Timeout Error
- Processing 25 brands takes ~50-60 seconds
- If using curl, increase timeout: `curl --max-time 120`
- If using browser, wait patiently

## Next Steps

After running this test successfully:

1. **Wait for daily cron** (runs at 23:00 UTC) to process the next 10 brands
2. **Or manually trigger:** `POST /api/cron/process-import-queue`
3. **Monitor queue:** Check `/api/v1/admin/import-queue` for progress
4. **Expected timeline:** ~11 days to process all 105 brands

## Success Criteria

✅ All 7 steps show `success: true`
✅ At least 20/25 brands have location data
✅ Total locations > 10,000
✅ Endpoint tests pass
✅ Queue shows 25 completed, 80 pending

---

**Ready to test? Run the curl command or browser console script above!**
