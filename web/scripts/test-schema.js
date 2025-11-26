#!/usr/bin/env node

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

async function testSchema() {
  const pool = new Pool({
    connectionString: process.env.POSTGRES_URL
  });

  const results = [];

  try {
    console.log('🔍 Testing schema.sql...\n');

    // Read schema file
    const schemaPath = path.join(__dirname, '..', 'db', 'schema.sql');
    const schemaSQL = fs.readFileSync(schemaPath, 'utf-8');
    console.log(`✅ Read schema file (${schemaSQL.length} bytes)\n`);

    // Execute entire schema as a single transaction
    console.log('📝 Executing entire schema file as single transaction\n');

    try {
      await pool.query(schemaSQL);
      console.log('✅ Schema executed successfully\n');
      results.push({ step: 'Execute full schema', success: true });
    } catch (error) {
      console.error('❌ Schema execution FAILED:');
      console.error(`   Error: ${error.message}\n`);
      results.push({
        step: 'Execute full schema',
        success: false,
        error: error.message
      });
    }

    // Test the functions
    console.log('🧪 Testing database functions...\n');

    try {
      const testQuery = await pool.query(`
        SELECT haversine_distance(34.0522, -118.2437, 34.0522, -118.2437) as distance
      `);
      console.log(`✅ haversine_distance function works: ${testQuery.rows[0].distance} meters`);
      results.push({
        step: 'Test haversine_distance',
        success: true,
        result: testQuery.rows[0]
      });
    } catch (error) {
      console.error('❌ haversine_distance function FAILED:');
      console.error(`   Error: ${error.message}\n`);
      results.push({
        step: 'Test haversine_distance',
        success: false,
        error: error.message
      });
    }

    try {
      const testQuery = await pool.query(`
        SELECT * FROM get_nearby_locations(34.0522, -118.2437, 10000, 5)
      `);
      console.log(`✅ get_nearby_locations function works: ${testQuery.rows.length} rows returned`);
      results.push({
        step: 'Test get_nearby_locations',
        success: true,
        rowCount: testQuery.rows.length
      });
    } catch (error) {
      console.error('❌ get_nearby_locations function FAILED:');
      console.error(`   Error: ${error.message}\n`);
      results.push({
        step: 'Test get_nearby_locations',
        success: false,
        error: error.message
      });
    }

    // Summary
    const successCount = results.filter(r => r.success).length;
    const failureCount = results.length - successCount;

    console.log(`\n${'='.repeat(60)}`);
    console.log(`📊 SUMMARY: ${successCount}/${results.length} steps successful`);
    if (failureCount > 0) {
      console.log(`❌ ${failureCount} failures`);
    }
    console.log(`${'='.repeat(60)}\n`);

    process.exit(failureCount > 0 ? 1 : 0);

  } catch (error) {
    console.error('\n💥 Fatal error:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

testSchema();
