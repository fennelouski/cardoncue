import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import fs from 'fs';
import path from 'path';

// Force dynamic rendering
export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

/**
 * GET /api/debug-schema
 * Public endpoint to test schema execution with detailed error reporting
 */
export async function GET(request: NextRequest) {
  let pool: Pool | null = null;
  const results: any[] = [];

  try {
    // Create pool
    pool = new Pool({
      connectionString: process.env.POSTGRES_URL
    });

    results.push({ step: 'Pool created', success: true });

    // Read schema file
    const schemaPath = path.join(process.cwd(), 'db', 'schema.sql');
    let schemaSQL: string;

    try {
      schemaSQL = fs.readFileSync(schemaPath, 'utf-8');
      results.push({
        step: 'Schema file read',
        success: true,
        path: schemaPath,
        size: schemaSQL.length
      });
    } catch (error: any) {
      results.push({
        step: 'Schema file read',
        success: false,
        error: error.message,
        path: schemaPath
      });
      throw error;
    }

    // Execute entire schema as a single transaction
    try {
      await pool.query(schemaSQL);
      results.push({
        step: 'Execute full schema',
        success: true
      });
    } catch (error: any) {
      results.push({
        step: 'Execute full schema',
        success: false,
        error: error.message
      });
    }

    // Test the functions
    try {
      const testQuery = await pool.query(`
        SELECT haversine_distance(34.0522, -118.2437, 34.0522, -118.2437) as distance
      `);
      results.push({
        step: 'Test haversine_distance function',
        success: true,
        result: testQuery.rows[0]
      });
    } catch (error: any) {
      results.push({
        step: 'Test haversine_distance function',
        success: false,
        error: error.message
      });
    }

    try {
      const testQuery = await pool.query(`
        SELECT * FROM get_nearby_locations(34.0522, -118.2437, 10000, 5)
      `);
      results.push({
        step: 'Test get_nearby_locations function',
        success: true,
        rowCount: testQuery.rows.length
      });
    } catch (error: any) {
      results.push({
        step: 'Test get_nearby_locations function',
        success: false,
        error: error.message
      });
    }

    const successCount = results.filter(r => r.success).length;
    const totalCount = results.length;

    return NextResponse.json({
      success: successCount === totalCount,
      message: `${successCount}/${totalCount} steps successful`,
      results
    });

  } catch (error: any) {
    return NextResponse.json({
      success: false,
      error: error.message,
      results
    }, { status: 500 });
  } finally {
    if (pool) {
      await pool.end();
    }
  }
}
