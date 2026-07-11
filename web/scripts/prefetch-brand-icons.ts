#!/usr/bin/env tsx

/**
 * Pre-fetch Brand Icons into brands.logo_url and Vercel KV cache.
 *
 * Usage:
 *   npx tsx scripts/prefetch-brand-icons.ts
 */

import { getDefaultIconForCard } from '../lib/services/iconService';
import { seedBrandLogos } from '../lib/services/brandService';
import queueData from './import-queue.json';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(__dirname, '..', '.env.production') });
dotenv.config({ path: path.join(__dirname, '..', '.env.local') });

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

  console.log('\n📋 Step 1: Seeding brands table and logo_url columns...\n');
  const seedResult = await seedBrandLogos(queueData.brands as any[]);
  console.log(`   Seeded: ${seedResult.seeded}, logos in DB: ${seedResult.logosFound}`);

  console.log(`\n📋 Step 2: Warming KV cache for ${queueData.brands.length} brands...\n`);

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
        failures++;
        results.push({
          brand: brand.name,
          success: false,
          error: 'No icon found (using placeholder)',
        });
        console.log(' ⚠️  No icon (placeholder)');
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
          source: result.source,
        });

        const icon = result.source === 'cache' ? '💾' : '🔍';
        console.log(` ${icon} ${result.source}`);
      }

      await new Promise((resolve) => setTimeout(resolve, 100));
    } catch (error: any) {
      failures++;
      results.push({
        brand: brand.name,
        success: false,
        error: error.message,
      });
      console.log(` ❌ Error: ${error.message}`);
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log('\n📊 Summary:\n');
  console.log(`   Total brands:        ${queueData.brands.length}`);
  console.log(`   ✅ Icons found:      ${successCount}`);
  console.log(`   💾 From cache:       ${cacheHits}`);
  console.log(`   🔍 New searches:     ${searches}`);
  console.log(`   ⚠️  No icon found:   ${failures}`);
  console.log(
    `   Success rate:        ${((successCount / queueData.brands.length) * 100).toFixed(1)}%`
  );

  if (failures > 0) {
    console.log('\n⚠️  Brands without icons:\n');
    results
      .filter((r) => !r.success)
      .forEach((r) => console.log(`   - ${r.brand}`));
  }

  console.log('\n' + '='.repeat(60));
  console.log('\n✨ Icon pre-fetch complete!\n');

  process.exit(0);
}

main().catch((error) => {
  console.error('\n❌ Fatal error:', error);
  process.exit(1);
});
