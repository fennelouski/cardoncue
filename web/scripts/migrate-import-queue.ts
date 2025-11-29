#!/usr/bin/env tsx

/**
 * Import Queue Migration Script
 *
 * Creates the import_queue table and related indexes/views
 *
 * Usage:
 *   npx tsx scripts/migrate-import-queue.ts
 */

import 'dotenv/config';
import { sql } from '@vercel/postgres';
import fs from 'fs';
import path from 'path';

async function migrate() {
  console.log('🚀 Starting import_queue migration...\n');

  try {
    // Read migration file
    const migrationPath = path.join(__dirname, '..', 'db', 'migrations', '008_import_queue.sql');
    const migrationSQL = fs.readFileSync(migrationPath, 'utf-8');

    console.log('📄 Running 008_import_queue.sql...');

    // Execute migration
    await sql.query(migrationSQL);

    console.log('✅ Migration successful!\n');
    console.log('Created:');
    console.log('  - import_queue table');
    console.log('  - Indexes for efficient queue processing');
    console.log('  - Trigger for updated_at timestamp');
    console.log('  - import_queue_stats view');

    // Verify table exists
    const result = await sql`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name = 'import_queue'
    `;

    if (result.rows.length > 0) {
      console.log('\n✓ Table verified: import_queue exists');
    } else {
      throw new Error('Table import_queue was not created');
    }

  } catch (error) {
    console.error('❌ Migration failed:');
    console.error(error);
    process.exit(1);
  }
}

// Run migration
migrate()
  .then(() => {
    console.log('\n✨ Import queue table is ready!');
    console.log('\n💡 Next step: Run populate-import-queue.ts to add brands');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
