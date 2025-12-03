#!/usr/bin/env tsx

/**
 * Pre-fetch Brand Icons
 *
 * This script pre-fetches and caches icons for all 105 brands in the import queue.
 * It uses the icon service to search for brand icons and cache them in Vercel KV.
 *
 * Usage:
 *   npx tsx scripts/prefetch-brand-icons.ts
 */

import { getDefaultIconForCard } from '../lib/services/iconService';
import queueData from './import-queue.json';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables
dotenv.config({ path: path.join(__dirname, '..', '.env.production') });

interface FetchResult {
  brand: string;
  success: boolean;
  iconUrl?: string;
  source?: string;
  error?: string;
}

async function main() {
  console.log('🎨 CardOnCue - Brand Icon Pre-Fetch\n');
  console.log('='.repeat(60));
  console.log(`\n📋 Fetching icons for ${queueData.brands.length} brands...\n`);

  const results: FetchResult[] = [];
  let successCount = 0;
  let cacheHits = 0;
  let searches = 0;
  let failures = 0;

  for (const brand of queueData.brands as any[]) {
    try {
      process.stdout.write(`[${results.length + 1}/${queueData.brands.length}] ${brand.name}...`);

      const result = await getDefaultIconForCard(brand.name);

      if (result.source === 'default') {
        // This means we couldn't find a real icon
        failures++;
        results.push({
          brand: brand.name,
          success: false,
          error: 'No icon found (using placeholder)'
        });
        console.log(` ⚠️  No icon (placeholder)`);
      } else {
        successCount++;
        if (result.source === 'cache') {
          cacheHits++;
        } else {
          searches++;
        }

        results.push({
          brand: brand.name,
          success: true,
          iconUrl: result.url,
          source: result.source
        });

        const icon = result.source === 'cache' ? '💾' : '🔍';
        console.log(` ${icon} ${result.source}`);
      }

      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 100));

    } catch (error: any) {
      failures++;
      results.push({
        brand: brand.name,
        success: false,
        error: error.message
      });
      console.log(` ❌ Error: ${error.message}`);
    }
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('\n📊 Summary:\n');
  console.log(`   Total brands:        ${queueData.brands.length}`);
  console.log(`   ✅ Icons found:      ${successCount}`);
  console.log(`   💾 From cache:       ${cacheHits}`);
  console.log(`   🔍 New searches:     ${searches}`);
  console.log(`   ⚠️  No icon found:   ${failures}`);
  console.log(`   Success rate:        ${((successCount / queueData.brands.length) * 100).toFixed(1)}%`);

  // Show failures
  if (failures > 0) {
    console.log('\n⚠️  Brands without icons:\n');
    results
      .filter(r => !r.success)
      .forEach(r => console.log(`   - ${r.brand}`));
  }

  // Show sample successful results
  console.log('\n✅ Sample successful results:\n');
  results
    .filter(r => r.success)
    .slice(0, 10)
    .forEach(r => console.log(`   - ${r.brand}: ${r.iconUrl?.substring(0, 60)}...`));

  console.log('\n' + '='.repeat(60));
  console.log(`\n✨ Icon pre-fetch complete! All icons are now cached in Vercel KV.\n`);

  process.exit(0);
}

main().catch(error => {
  console.error('\n❌ Fatal error:', error);
  process.exit(1);
});
