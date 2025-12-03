/**
 * Test Setup and Configuration
 *
 * Ensures the test environment is properly configured before running tests.
 */

import { sql } from '@/lib/db';

export async function setupTestDatabase() {
  console.log('Setting up test database...');

  try {
    // Check if database connection is available
    const result = await sql`SELECT 1 as test`;
    console.log('✅ Database connection successful');

    // Check if migrations have been run
    const tablesExist = await sql`
      SELECT
        (SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'cards')) as cards_exists,
        (SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'gift_card_brands')) as gift_card_brands_exists
    `;

    if (!tablesExist.rows[0].cards_exists) {
      console.warn('⚠️  Cards table does not exist - migrations may need to be run');
    } else {
      console.log('✅ Cards table exists');
    }

    if (!tablesExist.rows[0].gift_card_brands_exists) {
      console.warn('⚠️  gift_card_brands table does not exist - migration 009 needs to be run');
    } else {
      console.log('✅ gift_card_brands table exists');
    }

  } catch (error) {
    console.error('❌ Database setup failed:', error);
    throw error;
  }
}

export async function cleanupTestData() {
  console.log('Cleaning up test data...');

  try {
    await sql`DELETE FROM cards WHERE id LIKE 'test-%'`;
    await sql`DELETE FROM gift_card_brands WHERE id LIKE 'test-%'`;
    console.log('✅ Test data cleaned up');
  } catch (error) {
    console.error('❌ Cleanup failed:', error);
  }
}
