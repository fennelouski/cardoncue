#!/usr/bin/env tsx

/**
 * Migration script to create ai_cache table
 *
 * Run this to add the AI result caching system to your database.
 *
 * Usage:
 *   npx tsx scripts/migrate-ai-cache.ts
 */

import { sql } from '@vercel/postgres';
import * as fs from 'fs';
import * as path from 'path';

async function migrate() {
  try {
    console.log('🚀 Starting AI cache migration...\n');

    // Read the migration SQL file
    const migrationPath = path.join(__dirname, '..', 'db', 'migrations', '007_ai_cache.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf8');

    console.log('📝 Executing migration SQL...');

    // Execute the migration
    await sql.query(migrationSQL);

    console.log('✅ AI cache table created successfully!\n');

    // Verify the table was created
    const result = await sql`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name = 'ai_cache'
    `;

    if (result.rows.length > 0) {
      console.log('✅ Verified: ai_cache table exists\n');

      // Check indexes
      const indexes = await sql`
        SELECT indexname
        FROM pg_indexes
        WHERE tablename = 'ai_cache'
      `;

      console.log('📊 Created indexes:');
      indexes.rows.forEach(row => {
        console.log(`   - ${row.indexname}`);
      });

      console.log('\n✨ Migration completed successfully!');
      console.log('\n💡 Next steps:');
      console.log('   1. Deploy your application');
      console.log('   2. Test AI endpoints to verify caching works');
      console.log('   3. Monitor cache hit rates in Vercel logs\n');
    } else {
      console.error('❌ Table verification failed');
      process.exit(1);
    }

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    console.error('\nTroubleshooting:');
    console.error('   - Check your POSTGRES_URL environment variable');
    console.error('   - Ensure you have CREATE TABLE permissions');
    console.error('   - Check if table already exists\n');
    process.exit(1);
  }
}

// Run migration
migrate();
