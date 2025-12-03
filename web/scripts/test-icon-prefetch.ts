#!/usr/bin/env tsx

/**
 * Test Icon Prefetch System
 *
 * This script tests the icon prefetch functionality by:
 * 1. Testing the icon service directly
 * 2. Optionally testing the API endpoint
 *
 * Usage:
 *   npx tsx scripts/test-icon-prefetch.ts
 */

import { getDefaultIconForCard } from '../lib/services/iconService';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables
dotenv.config({ path: path.join(__dirname, '..', '.env.local') });

interface TestResult {
  brand: string;
  success: boolean;
  iconUrl?: string;
  source?: string;
  error?: string;
  duration: number;
}

const TEST_BRANDS = [
  'Costco',
  'Starbucks',
  'Target',
  'Walmart',
  'Amazon',
  'Apple',
  'McDonald\'s',
  'Nike',
  'Coca-Cola',
  'Disney'
];

async function testIconService() {
  console.log('🧪 Testing Icon Service\n');
  console.log('='.repeat(60));
  console.log(`\nTesting ${TEST_BRANDS.length} sample brands...\n`);

  const results: TestResult[] = [];
  let successCount = 0;
  let cacheHits = 0;
  let searches = 0;
  let failures = 0;

  for (const brand of TEST_BRANDS) {
    const startTime = Date.now();

    try {
      process.stdout.write(`[${results.length + 1}/${TEST_BRANDS.length}] ${brand}...`);

      const result = await getDefaultIconForCard(brand);
      const duration = Date.now() - startTime;

      if (result.source === 'default') {
        failures++;
        results.push({
          brand,
          success: false,
          error: 'No icon found (using placeholder)',
          duration
        });
        console.log(` ⚠️  No icon (${duration}ms)`);
      } else {
        successCount++;
        if (result.source === 'cache') {
          cacheHits++;
        } else {
          searches++;
        }

        results.push({
          brand,
          success: true,
          iconUrl: result.url,
          source: result.source,
          duration
        });

        const icon = result.source === 'cache' ? '💾' : '🔍';
        console.log(` ${icon} ${result.source} (${duration}ms)`);
      }

      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 100));

    } catch (error: any) {
      const duration = Date.now() - startTime;
      failures++;
      results.push({
        brand,
        success: false,
        error: error.message,
        duration
      });
      console.log(` ❌ Error: ${error.message} (${duration}ms)`);
    }
  }

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('\n📊 Test Summary:\n');
  console.log(`   Total brands tested: ${TEST_BRANDS.length}`);
  console.log(`   ✅ Icons found:      ${successCount}`);
  console.log(`   💾 From cache:       ${cacheHits}`);
  console.log(`   🔍 New searches:     ${searches}`);
  console.log(`   ⚠️  Failures:         ${failures}`);
  console.log(`   Success rate:        ${((successCount / TEST_BRANDS.length) * 100).toFixed(1)}%`);

  // Performance metrics
  const avgDuration = results.reduce((sum, r) => sum + r.duration, 0) / results.length;
  const maxDuration = Math.max(...results.map(r => r.duration));
  const minDuration = Math.min(...results.map(r => r.duration));

  console.log('\n⏱️  Performance:\n');
  console.log(`   Average time:        ${avgDuration.toFixed(0)}ms`);
  console.log(`   Min time:            ${minDuration}ms`);
  console.log(`   Max time:            ${maxDuration}ms`);

  // Show successful results
  if (successCount > 0) {
    console.log('\n✅ Successful icon lookups:\n');
    results
      .filter(r => r.success)
      .forEach(r => {
        const url = r.iconUrl?.substring(0, 70) + (r.iconUrl && r.iconUrl.length > 70 ? '...' : '');
        console.log(`   ${r.brand.padEnd(15)} ${r.source?.padEnd(8)} ${url}`);
      });
  }

  // Show failures
  if (failures > 0) {
    console.log('\n⚠️  Failed icon lookups:\n');
    results
      .filter(r => !r.success)
      .forEach(r => console.log(`   - ${r.brand}: ${r.error}`));
  }

  console.log('\n' + '='.repeat(60));
  console.log('\n');

  // Return test status
  return {
    passed: failures === 0,
    successCount,
    failures,
    totalTime: results.reduce((sum, r) => sum + r.duration, 0)
  };
}

async function testApiEndpoint(url: string) {
  console.log('\n🌐 Testing API Endpoint\n');
  console.log('='.repeat(60));
  console.log(`\nCalling: ${url}\n`);

  const startTime = Date.now();

  try {
    const response = await fetch(url);
    const duration = Date.now() - startTime;

    console.log(`Status: ${response.status} ${response.statusText}`);
    console.log(`Duration: ${duration}ms\n`);

    if (!response.ok) {
      console.log('❌ API endpoint returned error status');
      const text = await response.text();
      console.log(`Response: ${text.substring(0, 200)}...`);
      return false;
    }

    const data = await response.json();

    if (data.success) {
      console.log('✅ API endpoint test passed!\n');
      console.log('Summary:');
      console.log(`   Total brands:     ${data.summary.total}`);
      console.log(`   Icons found:      ${data.summary.successCount}`);
      console.log(`   From cache:       ${data.summary.cacheHits}`);
      console.log(`   New searches:     ${data.summary.searches}`);
      console.log(`   Failures:         ${data.summary.failures}`);
      console.log(`   Success rate:     ${data.summary.successRate}`);
      return true;
    } else {
      console.log('❌ API endpoint returned success: false');
      console.log(`Error: ${data.error || data.message}`);
      return false;
    }
  } catch (error: any) {
    console.log(`❌ Failed to call API endpoint: ${error.message}`);
    return false;
  }
}

async function main() {
  console.log('\n🎨 CardOnCue - Icon Prefetch Test Suite\n');

  // Test 1: Icon Service
  const serviceResult = await testIconService();

  // Test 2: API Endpoint (optional)
  const apiUrl = process.env.API_URL || process.argv[2];

  if (apiUrl) {
    await testApiEndpoint(apiUrl);
  } else {
    console.log('\n💡 Tip: To test the API endpoint, run:');
    console.log('   npx tsx scripts/test-icon-prefetch.ts https://www.cardoncue.com/api/admin/prefetch-icons');
  }

  // Final result
  console.log('\n' + '='.repeat(60));
  if (serviceResult.passed) {
    console.log('\n✅ All tests passed!\n');
    process.exit(0);
  } else {
    console.log(`\n⚠️  ${serviceResult.failures} test(s) failed\n`);
    process.exit(1);
  }
}

main().catch(error => {
  console.error('\n❌ Fatal error:', error);
  process.exit(1);
});
