#!/usr/bin/env tsx

/**
 * Populate Import Queue Script
 *
 * This script:
 * 1. Reads all 105 brands from import-queue.json
 * 2. Creates network records for each brand (if they don't exist)
 * 3. Adds each brand to the import_queue table for automated processing
 *
 * Usage:
 *   npx tsx scripts/populate-import-queue.ts
 */

import 'dotenv/config';
import { sql } from '@vercel/postgres';
import * as fs from 'fs';
import * as path from 'path';

interface Brand {
  priority: number;
  name: string;
  category: string;
}

interface ImportQueue {
  generated: string;
  description: string;
  totalBrands: number;
  brands: Brand[];
}

async function main() {
  console.log('🚀 CardOnCue Import Queue Population Script\n');

  // Read the import queue JSON
  const queuePath = path.join(__dirname, 'import-queue.json');
  const queueData: ImportQueue = JSON.parse(fs.readFileSync(queuePath, 'utf-8'));

  console.log(`📋 Found ${queueData.totalBrands} brands to import\n`);

  let networksCreated = 0;
  let networksExisted = 0;
  let queueItemsAdded = 0;
  let queueItemsSkipped = 0;

  // Process each brand
  for (const brand of queueData.brands) {
    try {
      console.log(`\n[${brand.priority}] Processing: ${brand.name} (${brand.category})`);

      // Step 1: Create or get network record
      let networkId: string;

      // Check if network already exists
      const existingNetwork = await sql`
        SELECT id FROM networks
        WHERE name = ${brand.name}
        LIMIT 1
      `;

      if (existingNetwork.rows.length > 0) {
        networkId = existingNetwork.rows[0].id;
        networksExisted++;
        console.log(`  ✓ Network exists: ${networkId}`);
      } else {
        // Create new network
        const newNetwork = await sql`
          INSERT INTO networks (name, category, type)
          VALUES (${brand.name}, ${brand.category}, 'chain')
          RETURNING id
        `;
        networkId = newNetwork.rows[0].id;
        networksCreated++;
        console.log(`  ✅ Created network: ${networkId}`);
      }

      // Step 2: Add to import queue (if not already there)
      const existingQueueItem = await sql`
        SELECT id, status FROM import_queue
        WHERE network_id = ${networkId}
          AND status IN ('pending', 'processing')
        LIMIT 1
      `;

      if (existingQueueItem.rows.length > 0) {
        queueItemsSkipped++;
        console.log(`  ⏭️  Already in queue: ${existingQueueItem.rows[0].status}`);
      } else {
        // Add to queue
        // Use center of US as default location (geographic center)
        const defaultLat = 39.8283;
        const defaultLon = -98.5795;

        await sql`
          INSERT INTO import_queue (
            network_id,
            network_name,
            priority,
            latitude,
            longitude,
            radius_km,
            added_by,
            added_reason
          ) VALUES (
            ${networkId},
            ${brand.name},
            ${brand.priority},
            ${defaultLat},
            ${defaultLon},
            100,
            'system',
            'initial'
          )
        `;

        queueItemsAdded++;
        console.log(`  ✅ Added to queue (priority: ${brand.priority})`);
      }

    } catch (error) {
      console.error(`  ❌ Error processing ${brand.name}:`, error);
    }

    // Rate limiting: Small delay between database operations
    await new Promise(resolve => setTimeout(resolve, 50));
  }

  // Final summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 SUMMARY\n');
  console.log(`Networks:`);
  console.log(`  Created: ${networksCreated}`);
  console.log(`  Already existed: ${networksExisted}`);
  console.log(`  Total: ${networksCreated + networksExisted}\n`);

  console.log(`Import Queue:`);
  console.log(`  Added: ${queueItemsAdded}`);
  console.log(`  Skipped (already in queue): ${queueItemsSkipped}`);
  console.log(`  Total: ${queueItemsAdded + queueItemsSkipped}\n`);

  // Get queue statistics
  const queueStats = await sql`SELECT * FROM import_queue_stats`;

  console.log('Queue Status:');
  for (const stat of queueStats.rows) {
    console.log(`  ${stat.status}: ${stat.count} items`);
  }

  console.log('\n✅ Queue population complete!');
  console.log('\n💡 Next steps:');
  console.log('  1. The cron job will process 10 items daily at 23:00 UTC');
  console.log('  2. Or manually trigger: POST /api/cron/process-import-queue');
  console.log('  3. Monitor queue: GET /api/v1/admin/import-queue\n');

  process.exit(0);
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
