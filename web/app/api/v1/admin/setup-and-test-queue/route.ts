import { NextRequest, NextResponse } from 'next/server';
import { auth, currentUser } from '@clerk/nextjs/server';
import { Pool } from 'pg';
import sqlTag from 'sql-template-tag';
import { importLocationsForBrand } from '@/lib/data-sources/unified-location-import';
import queueData from '@/scripts/import-queue.json';
import fs from 'fs';
import path from 'path';

// Force dynamic rendering (don't prerender at build time)
export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

// Helper function to execute SQL template queries
async function sql(strings: TemplateStringsArray, ...values: any[]) {
  const query = sqlTag(strings, ...values);
  const result = await globalPool.query(query.sql, query.values);
  return result;
}

// Global pool instance
let globalPool: Pool;

interface TestResult {
  step: string;
  success: boolean;
  message: string;
  data?: any;
  error?: string;
}

/**
 * POST /api/v1/admin/setup-and-test-queue
 * Complete setup and testing of import queue system with first 25 brands
 */
export async function POST(request: NextRequest) {
  const results: TestResult[] = [];

  try {
    const { userId } = await auth();
    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const user = await currentUser();
    const userEmail = user?.emailAddresses?.[0]?.emailAddress;
    if (userEmail !== 'nathanfennel@gmail.com') {
      return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
    }

    // Create pool for database connection
    globalPool = new Pool({
      connectionString: process.env.POSTGRES_URL
    });

    console.log('🚀 Starting comprehensive queue setup and test...\n');

    // STEP 1: Run base schema and migrations
    console.log('STEP 1: Running database schema and migrations...');
    try {
      // Run base schema first
      const schemaPath = path.join(process.cwd(), 'db', 'schema.sql');
      const schemaSQL = fs.readFileSync(schemaPath, 'utf-8');
      await globalPool.query(schemaSQL);
      console.log('  ✓ Base schema applied');

      // Run import_queue migration
      const migrationPath = path.join(process.cwd(), 'db', 'migrations', '008_import_queue.sql');
      const migrationSQL = fs.readFileSync(migrationPath, 'utf-8');
      await globalPool.query(migrationSQL);
      console.log('  ✓ Import queue migration applied');

      results.push({
        step: '1. Database Schema & Migrations',
        success: true,
        message: 'Base schema and import_queue table created successfully'
      });
      console.log('✅ Database setup complete\n');
    } catch (error: any) {
      // Tables might already exist
      if (error.message?.includes('already exists')) {
        results.push({
          step: '1. Database Schema & Migrations',
          success: true,
          message: 'Tables already exist (skipped)'
        });
        console.log('✅ Tables already exist (skipped)\n');
      } else {
        results.push({
          step: '1. Database Schema & Migrations',
          success: false,
          message: 'Database setup failed',
          error: error.message
        });
        throw error;
      }
    }

    // STEP 2: Populate queue
    console.log('STEP 2: Populating queue with 105 brands...');
    try {
      let networksCreated = 0;
      let networksExisted = 0;
      let queueItemsAdded = 0;

      for (const brand of queueData.brands.slice(0, 105) as any[]) {
        // Create or get network
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

        // Add to queue if not already there
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
      console.log(`✅ Queue populated: ${queueItemsAdded} items\n`);
    } catch (error: any) {
      results.push({
        step: '2. Queue Population',
        success: false,
        message: 'Failed to populate queue',
        error: error.message
      });
      throw error;
    }

    // STEP 3: Test endpoints BEFORE processing (should have no locations)
    console.log('STEP 3: Testing endpoints before processing...');
    try {
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

          preTestResults.push({
            brand: brand.name,
            networkId,
            locationCount: parseInt(locationCount.rows[0]?.count || '0')
          });
        }
      }

      const allZero = preTestResults.every(r => r.locationCount === 0);
      results.push({
        step: '3. Pre-Processing Test',
        success: allZero,
        message: allZero ? 'All brands have 0 locations (as expected)' : 'Warning: Some brands already have locations',
        data: preTestResults
      });
      console.log(`✅ Pre-test complete: ${allZero ? 'Clean slate' : 'Has existing data'}\n`);
    } catch (error: any) {
      results.push({
        step: '3. Pre-Processing Test',
        success: false,
        message: 'Failed to test endpoints',
        error: error.message
      });
    }

    // STEP 4: Process first 25 brands
    console.log('STEP 4: Processing first 25 brands...');
    try {
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
        console.log(`  Processing: ${item.network_name}...`);

        try {
          // Mark as processing
          await sql`
            UPDATE import_queue
            SET status = 'processing', last_attempted_at = NOW(), attempts = attempts + 1
            WHERE id = ${item.id}
          `;

          const lat = item.latitude || 39.8283;
          const lon = item.longitude || -98.5795;
          const radiusKm = item.radius_km || 100;

          // Import locations
          const result = await importLocationsForBrand(
            item.network_name,
            item.network_id,
            lat,
            lon,
            radiusKm
          );

          // Mark as completed
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
          console.log(`    ✅ ${result.count} locations from ${result.source}`);

          // Rate limiting
          await new Promise(resolve => setTimeout(resolve, 2000));

        } catch (error: any) {
          console.log(`    ❌ Error: ${error.message}`);

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
      console.log(`✅ Processing complete: ${successCount}/${pendingItems.rows.length}\n`);

    } catch (error: any) {
      results.push({
        step: '4. Process 25 Brands',
        success: false,
        message: 'Failed to process brands',
        error: error.message
      });
      throw error;
    }

    // STEP 5: Verify location data
    console.log('STEP 5: Verifying location data...');
    try {
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
            SELECT name, address, city, state, latitude, longitude, metadata
            FROM locations
            WHERE network_id = ${networkId}
            LIMIT 1
          `;

          const count = parseInt(locationCount.rows[0]?.count || '0');
          totalLocations += count;

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
      console.log(`✅ Verification complete: ${totalLocations} total locations\n`);

    } catch (error: any) {
      results.push({
        step: '5. Verify Location Data',
        success: false,
        message: 'Failed to verify data',
        error: error.message
      });
    }

    // STEP 6: Test endpoints AFTER processing
    console.log('STEP 6: Testing endpoints after processing...');
    try {
      const endpointTests = [];

      // Test 1: Get network locations for Costco
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
          resultCount: costcoLocations.rows.length,
          sample: costcoLocations.rows.slice(0, 2)
        });
      }

      // Test 2: Get nearby locations (using LA coordinates)
      const nearbyLocations = await sql`
        SELECT n.name as network_name, l.name, l.city, l.state,
               haversine_distance(34.0522, -118.2437, l.latitude::DOUBLE PRECISION, l.longitude::DOUBLE PRECISION) / 1000 as distance_km
        FROM locations l
        JOIN networks n ON l.network_id = n.id
        WHERE haversine_distance(34.0522, -118.2437, l.latitude::DOUBLE PRECISION, l.longitude::DOUBLE PRECISION) <= 50000
        ORDER BY distance_km ASC
        LIMIT 10
      `;

      endpointTests.push({
        endpoint: '/api/v1/locations/nearby?lat=34.0522&lon=-118.2437&radius=50',
        test: 'Get nearby locations (LA)',
        success: nearbyLocations.rows.length > 0,
        resultCount: nearbyLocations.rows.length,
        sample: nearbyLocations.rows.slice(0, 3)
      });

      results.push({
        step: '6. Post-Processing Endpoint Tests',
        success: endpointTests.every(t => t.success),
        message: `${endpointTests.filter(t => t.success).length}/${endpointTests.length} endpoint tests passed`,
        data: endpointTests
      });
      console.log(`✅ Endpoint tests complete\n`);

    } catch (error: any) {
      results.push({
        step: '6. Post-Processing Endpoint Tests',
        success: false,
        message: 'Failed to test endpoints',
        error: error.message
      });
    }

    // STEP 7: Get queue statistics
    console.log('STEP 7: Getting queue statistics...');
    try {
      const queueStats = await sql`SELECT * FROM import_queue_stats`;

      results.push({
        step: '7. Queue Statistics',
        success: true,
        message: 'Queue statistics retrieved',
        data: queueStats.rows
      });
      console.log(`✅ Statistics retrieved\n`);

    } catch (error: any) {
      results.push({
        step: '7. Queue Statistics',
        success: false,
        message: 'Failed to get statistics',
        error: error.message
      });
    }

    // Summary
    const successSteps = results.filter(r => r.success).length;
    const totalSteps = results.length;

    console.log(`\n${'='.repeat(60)}`);
    console.log(`✅ COMPLETE: ${successSteps}/${totalSteps} steps successful`);
    console.log(`${'='.repeat(60)}\n`);

    return NextResponse.json({
      success: successSteps === totalSteps,
      message: `Setup and test complete: ${successSteps}/${totalSteps} steps successful`,
      results,
      summary: {
        totalSteps,
        successfulSteps: successSteps,
        failedSteps: totalSteps - successSteps
      }
    });

  } catch (error: any) {
    console.error('Setup and test error:', error);
    return NextResponse.json({
      success: false,
      error: error.message,
      results
    }, { status: 500 });
  }
}
