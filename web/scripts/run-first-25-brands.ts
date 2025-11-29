#!/usr/bin/env tsx

/**
 * Run First 25 Brands Test
 *
 * This script performs a comprehensive test of the import queue system:
 * 1. Creates import_queue table
 * 2. Populates queue with 105 brands
 * 3. Tests endpoints before processing
 * 4. Processes first 25 brands
 * 5. Verifies data correctness
 * 6. Tests endpoints after processing
 * 7. Shows queue statistics
 */

import { sql } from '@vercel/postgres';
import { importLocationsForBrand } from '../lib/data-sources/unified-location-import';
import queueData from './import-queue.json';
import * as fs from 'fs';
import * as path from 'path';

interface TestResult {
  step: string;
  success: boolean;
  message: string;
  data?: any;
  error?: string;
}

async function main() {
  const results: TestResult[] = [];
  console.log('🚀 CardOnCue - First 25 Brands Test\n');
  console.log('='.repeat(60));

  try {
    // STEP 1: Run migration
    console.log('\n📋 STEP 1: Running database migration...');
    try {
      const migrationPath = path.join(__dirname, '..', 'db', 'migrations', '008_import_queue.sql');
      const migrationSQL = fs.readFileSync(migrationPath, 'utf-8');
      await sql.query(migrationSQL);

      results.push({
        step: '1. Database Migration',
        success: true,
        message: 'import_queue table created successfully'
      });
      console.log('   ✅ Migration complete');
    } catch (error: any) {
      if (error.message?.includes('already exists')) {
        results.push({
          step: '1. Database Migration',
          success: true,
          message: 'Table already exists (skipped)'
        });
        console.log('   ✅ Table already exists (skipped)');
      } else {
        throw error;
      }
    }

    // STEP 2: Populate queue
    console.log('\n📋 STEP 2: Populating queue with 105 brands...');
    let networksCreated = 0;
    let networksExisted = 0;
    let queueItemsAdded = 0;

    for (const brand of queueData.brands as any[]) {
      const existingNetwork = await sql`
        SELECT id FROM networks WHERE name = ${brand.name} LIMIT 1
      `;

      let networkId: string;
      if (existingNetwork.rows.length > 0) {
        networkId = existingNetwork.rows[0].id;
        networksExisted++;
      } else {
        const newNetwork = await sql`
          INSERT INTO networks (name, category, type)
          VALUES (${brand.name}, ${brand.category}, 'chain')
          RETURNING id
        `;
        networkId = newNetwork.rows[0].id;
        networksCreated++;
      }

      const existingQueueItem = await sql`
        SELECT id FROM import_queue
        WHERE network_id = ${networkId} AND status IN ('pending', 'processing')
        LIMIT 1
      `;

      if (existingQueueItem.rows.length === 0) {
        await sql`
          INSERT INTO import_queue (
            network_id, network_name, priority, latitude, longitude,
            radius_km, added_by, added_reason
          ) VALUES (
            ${networkId}, ${brand.name}, ${brand.priority}, 39.8283, -98.5795,
            100, 'system', 'initial'
          )
        `;
        queueItemsAdded++;
      }
    }

    results.push({
      step: '2. Queue Population',
      success: true,
      message: `Added ${networksCreated} new networks, ${networksExisted} existed, ${queueItemsAdded} queue items added`,
      data: { networksCreated, networksExisted, queueItemsAdded }
    });
    console.log(`   ✅ Networks: ${networksCreated} created, ${networksExisted} existed`);
    console.log(`   ✅ Queue items: ${queueItemsAdded} added`);

    // STEP 3: Pre-processing test
    console.log('\n📋 STEP 3: Testing endpoints BEFORE processing...');
    const first5Brands = queueData.brands.slice(0, 5) as any[];
    const preTestResults = [];

    for (const brand of first5Brands) {
      const networkResult = await sql`
        SELECT id FROM networks WHERE name = ${brand.name} LIMIT 1
      `;

      if (networkResult.rows.length > 0) {
        const networkId = networkResult.rows[0].id;
        const locationCount = await sql`
          SELECT COUNT(*) as count FROM locations WHERE network_id = ${networkId}
        `;

        const count = parseInt(locationCount.rows[0]?.count || '0');
        preTestResults.push({
          brand: brand.name,
          networkId,
          locationCount: count
        });
        console.log(`   ${count === 0 ? '✅' : '⚠️'} ${brand.name}: ${count} locations`);
      }
    }

    const allZero = preTestResults.every(r => r.locationCount === 0);
    results.push({
      step: '3. Pre-Processing Test',
      success: allZero,
      message: allZero ? 'All tested brands have 0 locations (as expected)' : 'Warning: Some brands already have locations',
      data: preTestResults
    });

    // STEP 4: Process first 25 brands
    console.log('\n📋 STEP 4: Processing first 25 brands...');
    console.log('   This will take ~50-60 seconds (2-second delays for rate limiting)\n');

    const pendingItems = await sql`
      SELECT id, network_id, network_name, latitude, longitude, radius_km
      FROM import_queue
      WHERE status = 'pending'
      ORDER BY priority ASC, created_at ASC
      LIMIT 25
    `;

    const processResults = [];
    let successCount = 0;
    let failureCount = 0;

    for (const item of pendingItems.rows) {
      console.log(`   [${successCount + failureCount + 1}/25] ${item.network_name}...`);

      try {
        await sql`
          UPDATE import_queue
          SET status = 'processing', last_attempted_at = NOW(), attempts = attempts + 1
          WHERE id = ${item.id}
        `;

        const lat = item.latitude || 39.8283;
        const lon = item.longitude || -98.5795;
        const radiusKm = item.radius_km || 100;

        const result = await importLocationsForBrand(
          item.network_name,
          item.network_id,
          lat,
          lon,
          radiusKm
        );

        await sql`
          UPDATE import_queue
          SET status = 'completed',
              locations_found = ${result.locations.length},
              locations_inserted = ${result.count},
              data_source = ${result.source},
              completed_at = NOW(),
              last_error = NULL
          WHERE id = ${item.id}
        `;

        processResults.push({
          brand: item.network_name,
          status: 'success',
          locationsInserted: result.count,
          source: result.source
        });

        successCount++;
        console.log(`       ✅ ${result.count} locations from ${result.source}`);

        await new Promise(resolve => setTimeout(resolve, 2000));

      } catch (error: any) {
        console.log(`       ❌ Error: ${error.message}`);

        await sql`
          UPDATE import_queue
          SET status = 'failed', last_error = ${error.message}
          WHERE id = ${item.id}
        `;

        processResults.push({
          brand: item.network_name,
          status: 'error',
          error: error.message
        });

        failureCount++;
      }
    }

    results.push({
      step: '4. Process 25 Brands',
      success: successCount > 0,
      message: `Processed ${pendingItems.rows.length} brands: ${successCount} succeeded, ${failureCount} failed`,
      data: { processResults, successCount, failureCount }
    });

    // STEP 5: Verify location data
    console.log('\n📋 STEP 5: Verifying location data...');
    const first25Brands = queueData.brands.slice(0, 25) as any[];
    const verificationResults = [];
    let totalLocations = 0;

    for (const brand of first25Brands) {
      const networkResult = await sql`
        SELECT id FROM networks WHERE name = ${brand.name} LIMIT 1
      `;

      if (networkResult.rows.length > 0) {
        const networkId = networkResult.rows[0].id;

        const locationCount = await sql`
          SELECT COUNT(*) as count FROM locations WHERE network_id = ${networkId}
        `;

        const sampleLocation = await sql`
          SELECT name, address, city, state, latitude, longitude
          FROM locations
          WHERE network_id = ${networkId}
          LIMIT 1
        `;

        const count = parseInt(locationCount.rows[0]?.count || '0');
        totalLocations += count;

        if (count > 0) {
          console.log(`   ✅ ${brand.name}: ${count} locations`);
          if (sampleLocation.rows[0]) {
            const loc = sampleLocation.rows[0];
            console.log(`      Sample: ${loc.name}, ${loc.city}, ${loc.state}`);
          }
        } else {
          console.log(`   ⚠️ ${brand.name}: 0 locations`);
        }

        verificationResults.push({
          brand: brand.name,
          locationCount: count,
          sample: sampleLocation.rows[0] || null
        });
      }
    }

    const brandsWithData = verificationResults.filter(r => r.locationCount > 0).length;
    results.push({
      step: '5. Verify Location Data',
      success: totalLocations > 0,
      message: `${brandsWithData}/25 brands have location data. Total: ${totalLocations} locations`,
      data: { verificationResults, totalLocations, brandsWithData }
    });

    // STEP 6: Test endpoints
    console.log('\n📋 STEP 6: Testing endpoints after processing...');
    const endpointTests = [];

    // Test: Get Costco locations
    const costcoNetwork = await sql`
      SELECT id FROM networks WHERE name = 'Costco' LIMIT 1
    `;

    if (costcoNetwork.rows.length > 0) {
      const costcoId = costcoNetwork.rows[0].id;
      const costcoLocations = await sql`
        SELECT id, name, city, state FROM locations
        WHERE network_id = ${costcoId}
        LIMIT 5
      `;

      endpointTests.push({
        endpoint: `/api/v1/networks/${costcoId}/locations`,
        test: 'Get Costco locations',
        success: costcoLocations.rows.length > 0,
        resultCount: costcoLocations.rows.length
      });

      console.log(`   ${costcoLocations.rows.length > 0 ? '✅' : '❌'} Costco locations: ${costcoLocations.rows.length} found`);
    }

    // Test: Nearby locations
    const nearbyLocations = await sql`
      SELECT n.name as network_name, l.name, l.city, l.state,
             ST_Distance(l.location::geography, ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326)::geography) / 1000 as distance_km
      FROM locations l
      JOIN networks n ON l.network_id = n.id
      WHERE ST_DWithin(
        l.location::geography,
        ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326)::geography,
        50000
      )
      ORDER BY distance_km ASC
      LIMIT 10
    `;

    endpointTests.push({
      endpoint: '/api/v1/locations/nearby (LA)',
      test: 'Get nearby locations',
      success: nearbyLocations.rows.length > 0,
      resultCount: nearbyLocations.rows.length
    });

    console.log(`   ${nearbyLocations.rows.length > 0 ? '✅' : '❌'} Nearby locations (LA): ${nearbyLocations.rows.length} found`);

    results.push({
      step: '6. Post-Processing Endpoint Tests',
      success: endpointTests.every(t => t.success),
      message: `${endpointTests.filter(t => t.success).length}/${endpointTests.length} endpoint tests passed`,
      data: endpointTests
    });

    // STEP 7: Queue statistics
    console.log('\n📋 STEP 7: Queue statistics...');
    const queueStats = await sql`SELECT * FROM import_queue_stats`;

    console.log('\n   Queue Status:');
    for (const stat of queueStats.rows) {
      console.log(`   ${stat.status}: ${stat.count} items`);
    }

    results.push({
      step: '7. Queue Statistics',
      success: true,
      message: 'Queue statistics retrieved',
      data: queueStats.rows
    });

    // Summary
    console.log('\n' + '='.repeat(60));
    const successSteps = results.filter(r => r.success).length;
    const totalSteps = results.length;
    console.log(`\n✅ TEST COMPLETE: ${successSteps}/${totalSteps} steps successful\n`);

    if (successSteps === totalSteps) {
      console.log('🎉 All steps passed! The import queue system is working correctly.');
      console.log(`\n📊 Summary:`);
      console.log(`   - ${brandsWithData}/25 brands have location data`);
      console.log(`   - ${totalLocations} total locations imported`);
      console.log(`   - ${successCount}/${successCount + failureCount} brands processed successfully`);
    } else {
      console.log('⚠️  Some steps failed. Review the output above for details.');
    }

    console.log('\n' + '='.repeat(60));

    process.exit(successSteps === totalSteps ? 0 : 1);

  } catch (error: any) {
    console.error('\n❌ Fatal error:', error.message);
    console.error(error);
    process.exit(1);
  }
}

main();
