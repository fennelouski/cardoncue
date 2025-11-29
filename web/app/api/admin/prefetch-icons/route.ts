import { NextResponse } from 'next/server';
import { getDefaultIconForCard } from '@/lib/services/iconService';
import queueData from '@/scripts/import-queue.json';

// Force this route to be dynamic (runtime only, not build time)
export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';
export const maxDuration = 300; // 5 minutes

interface FetchResult {
  brand: string;
  success: boolean;
  iconUrl?: string;
  source?: string;
  error?: string;
}

/**
 * Admin endpoint to pre-fetch icons for all brands
 * GET /api/admin/prefetch-icons
 */
export async function GET() {
  try {
    console.log('🎨 CardOnCue - Brand Icon Pre-Fetch');
    console.log('='.repeat(60));
    console.log(`\n📋 Fetching icons for ${queueData.brands.length} brands...\n`);

    const results: FetchResult[] = [];
    let successCount = 0;
    let cacheHits = 0;
    let searches = 0;
    let failures = 0;

    for (const brand of queueData.brands as any[]) {
      try {
        console.log(`[${results.length + 1}/${queueData.brands.length}] ${brand.name}...`);

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
    const summary = {
      total: queueData.brands.length,
      successCount,
      cacheHits,
      searches,
      failures,
      successRate: ((successCount / queueData.brands.length) * 100).toFixed(1) + '%',
      brandsWithoutIcons: results
        .filter(r => !r.success)
        .map(r => r.brand),
      sampleResults: results
        .filter(r => r.success)
        .slice(0, 10)
        .map(r => ({ brand: r.brand, iconUrl: r.iconUrl?.substring(0, 60) + '...' }))
    };

    console.log('\n' + '='.repeat(60));
    console.log('\n📊 Summary:');
    console.log(`   Total brands:        ${summary.total}`);
    console.log(`   ✅ Icons found:      ${summary.successCount}`);
    console.log(`   💾 From cache:       ${summary.cacheHits}`);
    console.log(`   🔍 New searches:     ${summary.searches}`);
    console.log(`   ⚠️  No icon found:   ${summary.failures}`);
    console.log(`   Success rate:        ${summary.successRate}`);

    return NextResponse.json({
      success: true,
      message: 'Icon pre-fetch complete',
      summary,
      results
    });
  } catch (error: any) {
    console.error('Fatal error:', error);
    return NextResponse.json({
      success: false,
      message: 'Icon pre-fetch failed',
      error: error.message
    }, { status: 500 });
  }
}
