#!/usr/bin/env tsx

/**
 * Seed brands table from import queue and prefetch logos into brands.logo_url.
 *
 * Usage:
 *   npx tsx scripts/seed-brand-logos.ts
 */

import { seedBrandLogos } from '../lib/services/brandService';
import { determineDomainForBrand, normalizeBrandName } from '../lib/services/brandDomainMappings';
import queueData from './import-queue.json';
import * as dotenv from 'dotenv';
import * as path from 'path';
import * as fs from 'fs';

dotenv.config({ path: path.join(__dirname, '..', '.env.production') });
dotenv.config({ path: path.join(__dirname, '..', '.env.local') });

async function main() {
  console.log('🌱 CardOnCue - Seed Brand Logos\n');
  console.log('='.repeat(60));

  const brands = queueData.brands as Array<{ name: string; category: string }>;
  console.log(`\nProcessing ${brands.length} brands...\n`);

  const result = await seedBrandLogos(brands);

  console.log('\n📊 Summary:\n');
  console.log(`   New brands seeded:  ${result.seeded}`);
  console.log(`   Logos found:        ${result.logosFound}`);
  console.log(`   Failures:           ${result.failures.length}`);

  if (result.failures.length > 0) {
    console.log('\n⚠️  Brands without Logo.dev logos:\n');
    result.failures.slice(0, 20).forEach((name) => console.log(`   - ${name}`));
    if (result.failures.length > 20) {
      console.log(`   ... and ${result.failures.length - 20} more`);
    }
  }

  const snapshotPath = path.join(
    __dirname,
    '..',
    '..',
    'CardOnCue',
    'Resources',
    'brand_registry_snapshot.json'
  );

  fs.mkdirSync(path.dirname(snapshotPath), { recursive: true });

  const snapshotBrands = brands.map((brand) => ({
    name: normalizeBrandName(brand.name),
    displayName: brand.name,
    domain: determineDomainForBrand(brand.name),
    category: brand.category,
    logoUrl: null,
    verified: false,
  }));

  fs.writeFileSync(
    snapshotPath,
    JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        count: snapshotBrands.length,
        brands: snapshotBrands,
      },
      null,
      2
    )
  );

  console.log(`\n📦 Wrote iOS snapshot: ${snapshotPath}`);
  console.log('\n' + '='.repeat(60));
  console.log('\n✨ Brand seed complete!\n');

  process.exit(0);
}

main().catch((error) => {
  console.error('\n❌ Fatal error:', error);
  process.exit(1);
});
