#!/usr/bin/env npx tsx

/**
 * Manual test script for gift card functionality
 *
 * Run with: npx tsx scripts/test-gift-cards.ts
 */

import { sql } from '../lib/db';

async function testGiftCardFeature() {
  console.log('🧪 Testing Gift Card Feature\n');

  try {
    // Test 1: Check if migration ran
    console.log('1️⃣  Checking database schema...');
    const schemaCheck = await sql`
      SELECT
        (SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'gift_card_brands')) as brands_table,
        (SELECT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'cards' AND column_name = 'card_type')) as card_type_column,
        (SELECT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'cards' AND column_name = 'gift_card_brand_id')) as brand_id_column
    `;

    const schema = schemaCheck.rows[0];
    console.log('   gift_card_brands table:', schema.brands_table ? '✅' : '❌');
    console.log('   cards.card_type column:', schema.card_type_column ? '✅' : '❌');
    console.log('   cards.gift_card_brand_id column:', schema.brand_id_column ? '✅' : '❌');

    if (!schema.brands_table || !schema.card_type_column || !schema.brand_id_column) {
      console.log('\n❌ Migration not complete. Please run: psql $DATABASE_URL -f web/db/migrations/009_gift_cards.sql\n');
      return;
    }

    // Test 2: Create a test gift card brand
    console.log('\n2️⃣  Creating test gift card brand...');
    await sql`
      INSERT INTO gift_card_brands (
        id, name, issuer, description, accepted_network_ids, category, auto_discovered
      )
      VALUES (
        'test-darden-gift-card',
        'Darden Restaurants Gift Card',
        'Darden Restaurants Inc.',
        'Multi-restaurant gift card that works at Red Lobster, Olive Garden, LongHorn Steakhouse, and more',
        ARRAY['red-lobster', 'olive-garden', 'longhorn-steakhouse', 'bahama-breeze', 'seasons-52'],
        'restaurant',
        false
      )
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        accepted_network_ids = EXCLUDED.accepted_network_ids,
        updated_at = NOW()
      RETURNING *
    `;
    console.log('   ✅ Gift card brand created');

    // Test 3: Query the brand
    console.log('\n3️⃣  Querying gift card brand...');
    const brandResult = await sql`
      SELECT * FROM gift_card_brands WHERE id = 'test-darden-gift-card'
    `;
    const brand = brandResult.rows[0];
    console.log('   Name:', brand.name);
    console.log('   Issuer:', brand.issuer);
    console.log('   Accepts at:', brand.accepted_network_ids.length, 'networks');
    console.log('   Networks:', brand.accepted_network_ids.join(', '));

    // Test 4: Create a gift card
    console.log('\n4️⃣  Creating test gift card...');
    await sql`
      INSERT INTO cards (
        id, user_id, name, barcode_type, payload_encrypted,
        card_type, gift_card_brand_id, network_ids, tags
      )
      VALUES (
        'test-gift-card-001',
        'test-user-123',
        'My Darden Gift Card',
        'qr',
        'test-encrypted-payload-12345',
        'gift_card',
        'test-darden-gift-card',
        ARRAY[]::text[],
        ARRAY['gift-card', 'restaurant']
      )
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        card_type = EXCLUDED.card_type,
        gift_card_brand_id = EXCLUDED.gift_card_brand_id
      RETURNING *
    `;
    console.log('   ✅ Gift card created');

    // Test 5: Query card with brand info
    console.log('\n5️⃣  Querying gift card with brand details...');
    const cardResult = await sql`
      SELECT
        c.id,
        c.name as card_name,
        c.card_type,
        g.name as brand_name,
        g.issuer,
        g.accepted_network_ids,
        array_length(g.accepted_network_ids, 1) as num_locations
      FROM cards c
      LEFT JOIN gift_card_brands g ON c.gift_card_brand_id = g.id
      WHERE c.id = 'test-gift-card-001'
    `;
    const card = cardResult.rows[0];
    console.log('   Card Name:', card.card_name);
    console.log('   Card Type:', card.card_type);
    console.log('   Brand:', card.brand_name);
    console.log('   Works at:', card.num_locations, 'merchant networks');
    console.log('   Networks:', card.accepted_network_ids.join(', '));

    // Test 6: Simulate region refresh
    console.log('\n6️⃣  Simulating region refresh with gift card...');
    const giftCardBrandIds = ['test-darden-gift-card'];
    const brandsResult = await sql`
      SELECT accepted_network_ids
      FROM gift_card_brands
      WHERE id = ANY(${giftCardBrandIds})
    `;

    let relevantNetworkIds: string[] = [];
    for (const brand of brandsResult.rows) {
      if (brand.accepted_network_ids) {
        relevantNetworkIds.push(...brand.accepted_network_ids);
      }
    }

    console.log('   Gift cards accept these networks:', relevantNetworkIds.join(', '));
    console.log('   ✅ Region refresh would monitor', relevantNetworkIds.length, 'network types');

    // Test 7: Cleanup
    console.log('\n7️⃣  Cleaning up test data...');
    await sql`DELETE FROM cards WHERE id = 'test-gift-card-001'`;
    await sql`DELETE FROM gift_card_brands WHERE id = 'test-darden-gift-card'`;
    console.log('   ✅ Test data cleaned up');

    console.log('\n✅ All tests passed!\n');

  } catch (error: any) {
    console.error('\n❌ Test failed:', error.message);
    console.error('Stack:', error.stack);
    process.exit(1);
  }
}

// Run tests
testGiftCardFeature().then(() => {
  console.log('Done!');
  process.exit(0);
}).catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
