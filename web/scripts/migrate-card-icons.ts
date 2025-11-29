#!/usr/bin/env tsx

/**
 * Migration script to add card icon fields to cards table
 *
 * Run this to add the icon customization system to your database.
 *
 * Usage:
 *   npx tsx scripts/migrate-card-icons.ts
 */

import * as dotenv from 'dotenv';
import { createClient } from '@vercel/postgres';
import * as fs from 'fs';
import * as path from 'path';

// Load environment variables from .env.local
dotenv.config({ path: path.join(__dirname, '..', '.env.local') });

async function migrate() {
  const client = createClient({
    connectionString: process.env.POSTGRES_URL || process.env.DATABASE_URL,
  });

  try {
    console.log('🚀 Starting card icons migration...\n');

    // Connect to database
    await client.connect();

    // Read the migration SQL file
    const migrationPath = path.join(__dirname, '..', 'db', 'migrations', '008_card_icons.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');

    console.log('📝 Executing migration SQL...');

    // Execute the migration
    await client.query(migrationSQL);

    console.log('✅ Card icon columns added successfully!\n');

    // Verify the columns were created
    const result = await client.query(`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'cards'
        AND column_name IN ('default_icon_url', 'custom_icon_url', 'icon_blob_id')
    `);

    if (result.rows.length === 3) {
      console.log('✅ Verified: all icon columns exist\n');

      console.log('📊 Created columns:');
      result.rows.forEach(row => {
        console.log(`   - ${row.column_name} (${row.data_type})`);
      });

      console.log('\n✨ Migration completed successfully!');
      console.log('\n💡 Next steps:');
      console.log('   1. Deploy your application');
      console.log('   2. Test icon endpoints to verify functionality');
      console.log('   3. Populate default icons for existing cards\n');
    } else {
      console.error('❌ Column verification failed');
      await client.end();
      process.exit(1);
    }

    await client.end();
    process.exit(0);
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    console.error('\nTroubleshooting:');
    console.error('   - Check your POSTGRES_URL environment variable');
    console.error('   - Ensure you have ALTER TABLE permissions');
    console.error('   - Check if columns already exist\n');
    await client.end().catch(() => {});
    process.exit(1);
  }
}

// Run migration
migrate();
