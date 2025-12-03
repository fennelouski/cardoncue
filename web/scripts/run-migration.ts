#!/usr/bin/env npx tsx

/**
 * Migration runner script
 * Run with: npx tsx scripts/run-migration.ts <migration-file>
 */

import { config } from 'dotenv';
import { sql } from '../lib/db';
import fs from 'fs';
import path from 'path';

// Load .env.production
config({ path: path.join(__dirname, '..', '.env.production') });

async function runMigration(migrationFile: string) {
  console.log(`🔄 Running migration: ${migrationFile}\n`);

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
    await sql.query(migrationSQL);

    console.log('✅ Migration completed successfully!\n');

    // Verify the changes based on migration file
    console.log('🔍 Verifying changes...');

    // Determine what to verify based on the migration file
    if (migrationFile.includes('gift_cards')) {
      // Check if gift_card_brands table exists
      const tableCheck = await sql`
        SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_name = 'gift_card_brands'
        );
      `;
      console.log('  gift_card_brands table:', tableCheck.rows[0].exists ? '✅' : '❌');

      // Check if card_type column exists
      const columnCheck = await sql`
        SELECT EXISTS (
          SELECT FROM information_schema.columns
          WHERE table_name = 'cards'
          AND column_name = 'card_type'
        );
      `;
      console.log('  cards.card_type column:', columnCheck.rows[0].exists ? '✅' : '❌');

      // Check if gift_card_brand_id column exists
      const brandIdCheck = await sql`
        SELECT EXISTS (
          SELECT FROM information_schema.columns
          WHERE table_name = 'cards'
          AND column_name = 'gift_card_brand_id'
        );
      `;
      console.log('  cards.gift_card_brand_id column:', brandIdCheck.rows[0].exists ? '✅' : '❌');
    } else if (migrationFile.includes('card_locations')) {
      // Check if card_locations table exists
      const tableCheck = await sql`
        SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_name = 'card_locations'
        );
      `;
      console.log('  card_locations table:', tableCheck.rows[0].exists ? '✅' : '❌');

      // Check if required indexes exist
      const indexCheck = await sql`
        SELECT EXISTS (
          SELECT FROM pg_indexes
          WHERE tablename = 'card_locations'
          AND indexname = 'idx_card_locations_card_id'
        );
      `;
      console.log('  idx_card_locations_card_id index:', indexCheck.rows[0].exists ? '✅' : '❌');
    }

    console.log('\n🎉 All done!');
    process.exit(0);

  } catch (error: any) {
    console.error('\n❌ Migration failed:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  }
}

// Get migration file from command line args
const migrationFile = process.argv[2] || '009_gift_cards.sql';
runMigration(migrationFile);
