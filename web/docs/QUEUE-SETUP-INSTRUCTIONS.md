# Import Queue Setup Instructions

## Overview

The automated import queue system is now ready! This system will:
- Process 10 brands daily at 23:00 UTC
- Automatically queue missing locations when users add cards
- Import location data from OpenStreetMap (free)
- Track progress and statistics

## Setup Steps (Run After Deployment)

### Step 1: Run Database Migration

Create the `import_queue` table and related infrastructure:

```bash
curl -X POST https://cardoncue.com/api/v1/admin/migrate?migration=008_import_queue \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION"
```

This creates:
- `import_queue` table
- Indexes for efficient processing
- Triggers for automatic timestamps
- `import_queue_stats` view

### Step 2: Populate Queue with 105 Brands

Add all 105 brands (Costco, gyms, grocery stores, etc.) to the queue:

```bash
curl -X POST https://cardoncue.com/api/v1/admin/populate-queue \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION"
```

This will:
- Create network records for all 105 brands
- Add them to the import queue with priorities
- Skip any that are already in the queue

Expected output:
```json
{
  "success": true,
  "message": "Queue populated successfully",
  "summary": {
    "networks": {
      "created": 105,
      "existed": 0,
      "total": 105
    },
    "queue": {
      "added": 105,
      "skipped": 0,
      "total": 105
    }
  }
}
```

### Step 3: Set CRON_SECRET Environment Variable

Generate a random secret for cron authentication:

```bash
# Generate a random secret
openssl rand -base64 32

# Add to Vercel environment variables
vercel env add CRON_SECRET production
# Paste the generated secret when prompted
```

Or via Vercel Dashboard:
1. Go to Project Settings → Environment Variables
2. Add: `CRON_SECRET` = `[your-random-secret]`
3. Select: Production
4. Save

### Step 4: Verify Cron Configuration

The cron job is configured in `vercel.json` to run at 23:00 UTC daily:

```json
{
  "crons": [{
    "path": "/api/cron/process-import-queue",
    "schedule": "0 23 * * *"
  }]
}
```

Vercel will automatically register this cron job on deployment.

## Manual Testing

### Test Migration Endpoint

List available migrations:
```bash
curl https://cardoncue.com/api/v1/admin/migrate \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION"
```

### View Queue Status

```bash
curl "https://cardoncue.com/api/v1/admin/import-queue?status=pending" \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION"
```

### Manually Trigger Queue Processing

Test the cron job manually (processes next 10 items):
```bash
curl -X POST https://cardoncue.com/api/cron/process-import-queue \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION"
```

This will:
- Process the next 10 pending items from the queue
- Import locations from OpenStreetMap
- Update status to 'completed' or 'failed'
- Add 2-second delays between requests (rate limiting)

## Queue Management

### View Queue Statistics

```bash
curl "https://cardoncue.com/api/v1/admin/import-queue?status=pending" \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION"
```

Returns:
- Number of items by status (pending, processing, completed, failed)
- Average locations found
- Average attempts
- Oldest/newest items

### Add Items to Queue

```bash
curl -X POST https://cardoncue.com/api/v1/admin/import-queue \
  -H "Content-Type: application/json" \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION" \
  -d '{
    "networkId": "net_xxx",
    "networkName": "Costco",
    "priority": 10,
    "latitude": 34.0522,
    "longitude": -118.2437,
    "radiusKm": 100,
    "addedReason": "manual"
  }'
```

### Remove Items from Queue

Remove specific item:
```bash
curl -X DELETE "https://cardoncue.com/api/v1/admin/import-queue?id=QUEUE_ID" \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION"
```

Clear all completed items:
```bash
curl -X DELETE "https://cardoncue.com/api/v1/admin/import-queue?clearCompleted=true" \
  -H "Cookie: __clerk_db_jwt=YOUR_SESSION"
```

## How It Works

### Daily Automated Processing

1. **23:00 UTC Daily**: Vercel triggers `/api/cron/process-import-queue`
2. **Authentication**: Verifies `CRON_SECRET` header
3. **Fetch Items**: Gets next 10 pending items (ordered by priority)
4. **Process Each**:
   - Mark as 'processing'
   - Call OpenStreetMap API
   - Insert locations into database
   - Mark as 'completed' or 'failed'
   - Wait 2 seconds (rate limiting)
5. **Retry Logic**: Failed items retry up to 3 times

### User-Triggered Queueing

When a user creates a card via `POST /api/v1/cards`:

1. Check if card's networks have locations in database
2. If network has 0 locations → add to queue (high priority: 10)
3. Skip if already in queue
4. Queue will be processed at next 23:00 UTC cycle

### Priority System

- **1-10**: Critical (user-triggered, warehouse clubs)
- **11-50**: High (popular gyms, grocery stores)
- **51-100**: Normal (regional chains, coffee shops)
- **101+**: Low (long-tail brands)

## Expected Timeline

With 105 brands and 10 items/day:
- **Day 1**: Process first 10 brands (Costco, Sam's Club, top gyms)
- **Day 2**: Process next 10 brands
- **Day 11**: All 105 brands completed
- **Total locations**: ~15,000-25,000 (estimated)
- **Total cost**: $0 (OpenStreetMap is free!)

User-triggered imports (high priority) will be processed first.

## Monitoring

### Check Logs

View Vercel logs for cron execution:
```bash
vercel logs --follow
```

Look for:
- `🕐 Starting daily import queue processing...`
- `📋 Found X items to process`
- `✅ Imported X locations for BRAND`
- `✅ Completed processing: X succeeded, Y failed`

### Database Queries

Check queue status:
```sql
SELECT * FROM import_queue_stats;
```

View recent completions:
```sql
SELECT
  network_name,
  locations_inserted,
  data_source,
  completed_at
FROM import_queue
WHERE status = 'completed'
ORDER BY completed_at DESC
LIMIT 10;
```

Check failures:
```sql
SELECT
  network_name,
  last_error,
  attempts,
  last_attempted_at
FROM import_queue
WHERE status = 'failed'
ORDER BY last_attempted_at DESC;
```

## Troubleshooting

### Cron Not Running

1. Verify `CRON_SECRET` is set in Vercel environment
2. Check Vercel Dashboard → Cron Jobs
3. Ensure `vercel.json` has correct cron configuration
4. Redeploy if needed: `vercel --prod`

### No Locations Found

Some brands may have limited OpenStreetMap coverage:
1. Check OpenStreetMap data: https://overpass-turbo.eu/
2. Try different brand name variations
3. Configure Google Places API as fallback (optional)

### Rate Limit Errors

OpenStreetMap has rate limits:
- Default: 2 requests/second
- Our system: 2-second delays (respects limits)
- If issues persist, reduce items per day from 10 to 5

### Database Connection Issues

If migrations fail:
1. Ensure Vercel Postgres is linked to project
2. Check `POSTGRES_URL` is set in environment
3. Verify database permissions

## Success Metrics

After 11 days, you should have:
- ✅ 105 brands in database
- ✅ 15,000-25,000 locations
- ✅ 90%+ brands with locations
- ✅ $0 API costs (OpenStreetMap is free!)
- ✅ Automated daily processing

## Next Steps

1. ✅ Deploy code (includes queue system)
2. ⏳ Run Step 1: Migrate database
3. ⏳ Run Step 2: Populate queue
4. ⏳ Set CRON_SECRET environment variable
5. ⏳ Wait for first cron run at 23:00 UTC
6. ⏳ Monitor logs and database

---

**Questions?** Check the logs or run manual tests to verify everything is working correctly!
