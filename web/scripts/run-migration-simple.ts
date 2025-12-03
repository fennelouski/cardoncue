#!/usr/bin/env npx tsx

/**
 * Simple migration runner script using pg directly
 * Run with: npx tsx scripts/run-migration-simple.ts <migration-file>
 */

import { config } from 'dotenv';
import { Pool } from 'pg';
import fs from 'fs';
import path from 'path';

// Load .env.production
config({ path: path.join(__dirname, '..', '.env.production') });

async function runMigration(migrationFile: string) {
  console.log(`🔄 Running migration: ${migrationFile}\n`);

  // Clean up the connection string (remove any trailing whitespace/newlines)
  const connectionString = process.env.POSTGRES_URL?.trim();

  if (!connectionString) {
    throw new Error('POSTGRES_URL environment variable is not set');
  }

  const pool = new Pool({ connectionString });

  try {
    // Read the migration SQL file
    const migrationPath = path.join(__dirname, '..', 'db', 'migrations', migrationFile);

    if (!fs.existsSync(migrationPath)) {
      throw new Error(`Migration file not found: ${migrationPath}`);
    }

    const migrationSQL = fs.readFileSync(migrationPath, 'utf-8');

    console.log('📝 Migration SQL:');
    console.log('─'.repeat(60));
    console.log(migrationSQL);
    console.log('─'.repeat(60));
    console.log();

    // Execute the migration
    console.log('⏳ Executing migration...');
    await pool.query(migrationSQL);

    console.log('✅ Migration completed successfully!\n');

    // Verify the changes based on migration file
    console.log('🔍 Verifying changes...');

    if (migrationFile.includes('card_locations')) {
      // Check if card_locations table exists
      const tableCheck = await pool.query(`
        SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_name = 'card_locations'
        );
      `);
      console.log('  card_locations table:', tableCheck.rows[0].exists ? '✅' : '❌');

      // Check if required indexes exist
      const indexCheck = await pool.query(`
        SELECT EXISTS (
          SELECT FROM pg_indexes
          WHERE tablename = 'card_locations'
          AND indexname = 'idx_card_locations_card_id'
        );
      `);
      console.log('  idx_card_locations_card_id index:', indexCheck.rows[0].exists ? '✅' : '❌');
    }

    console.log('\n🎉 All done!');
    await pool.end();
    process.exit(0);

  } catch (error: any) {
    console.error('\n❌ Migration failed:', error.message);
    console.error('Stack:', error.stack);
    await pool.end();
    process.exit(1);
  }
}

// Get migration file from command line args
const migrationFile = process.argv[2] || '011_card_locations.sql';
runMigration(migrationFile);
