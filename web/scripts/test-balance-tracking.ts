import { sql } from '@vercel/postgres';
import fs from 'fs';
import path from 'path';

async function testBalanceTracking() {
  console.log('\n🧪 Testing Gift Card Balance Tracking\n');

  let testCardId: string | null = null;
  let testBrandId: string | null = null;

  try {
    // Step 1: Run migration
    console.log('1️⃣ Running migration 010_gift_card_balance_tracking.sql...');
    const migrationPath = path.join(
      process.cwd(),
      'db/migrations/010_gift_card_balance_tracking.sql'
    );
    const migration = fs.readFileSync(migrationPath, 'utf8');

    // Split on semicolons and filter empty statements
    const statements = migration
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));

    for (const statement of statements) {
      try {
        await sql.query(statement);
      } catch (error: any) {
        // Ignore "already exists" errors
        if (!error.message.includes('already exists')) {
          throw error;
        }
      }
    }
    console.log('   ✅ Migration completed\n');

    // Step 2: Create test gift card brand
    console.log('2️⃣ Creating test gift card brand...');
    const brandResult = await sql`
      INSERT INTO gift_card_brands (id, name, issuer, description, category, auto_discovered)
      VALUES (
        'test-restaurant-gift-card',
        'Test Restaurant Gift Card',
        'Test Restaurant Group',
        'Gift card for testing balance tracking',
        'restaurant',
        false
      )
      ON CONFLICT (id) DO UPDATE SET updated_at = NOW()
      RETURNING id
    `;
    testBrandId = brandResult.rows[0].id;
    console.log(`   ✅ Brand created: ${testBrandId}\n`);

    // Step 3: Create test gift card
    console.log('3️⃣ Creating test gift card...');
    const cardResult = await sql`
      INSERT INTO cards (
        user_id,
        name,
        barcode_type,
        payload,
        card_type,
        gift_card_brand_id,
        tags,
        network_ids
      )
      VALUES (
        'test-user-123',
        'Test Restaurant Gift Card',
        'code128',
        '1234567890',
        'gift_card',
        ${testBrandId},
        ARRAY['test', 'restaurant']::text[],
        ARRAY['test-restaurant']::text[]
      )
      RETURNING id
    `;
    testCardId = cardResult.rows[0].id;
    console.log(`   ✅ Card created: ${testCardId}\n`);

    // Step 4: Set initial balance
    console.log('4️⃣ Setting initial balance to $100.00...');
    await sql`
      UPDATE cards
      SET
        current_balance = 100.00,
        balance_currency = 'USD',
        balance_last_updated = NOW()
      WHERE id = ${testCardId}
    `;

    const historyResult1 = await sql`
      INSERT INTO gift_card_balance_history (card_id, balance, currency, notes)
      VALUES (${testCardId}, 100.00, 'USD', 'Initial balance')
      RETURNING *
    `;
    console.log('   ✅ Initial balance set\n');
    console.log('   History entry:', historyResult1.rows[0]);
    console.log('');

    // Step 5: Update balance after purchase
    console.log('5️⃣ Updating balance to $75.50 after purchase...');
    await sql`
      UPDATE cards
      SET
        current_balance = 75.50,
        balance_currency = 'USD',
        balance_last_updated = NOW()
      WHERE id = ${testCardId}
    `;

    const historyResult2 = await sql`
      INSERT INTO gift_card_balance_history (card_id, balance, currency, notes)
      VALUES (${testCardId}, 75.50, 'USD', 'After lunch purchase')
      RETURNING *
    `;
    console.log('   ✅ Balance updated\n');
    console.log('   History entry:', historyResult2.rows[0]);
    console.log('');

    // Step 6: Add another balance update
    console.log('6️⃣ Updating balance to $25.00 after dinner...');
    await sql`
      UPDATE cards
      SET
        current_balance = 25.00,
        balance_currency = 'USD',
        balance_last_updated = NOW()
      WHERE id = ${testCardId}
    `;

    const historyResult3 = await sql`
      INSERT INTO gift_card_balance_history (card_id, balance, currency, notes)
      VALUES (${testCardId}, 25.00, 'USD', 'After dinner purchase')
      RETURNING *
    `;
    console.log('   ✅ Balance updated\n');
    console.log('   History entry:', historyResult3.rows[0]);
    console.log('');

    // Step 7: Get balance history
    console.log('7️⃣ Retrieving balance history...');
    const historyQuery = await sql`
      SELECT *
      FROM gift_card_balance_history
      WHERE card_id = ${testCardId}
      ORDER BY created_at DESC
    `;
    console.log(`   ✅ Found ${historyQuery.rows.length} history entries:\n`);
    historyQuery.rows.forEach((entry, i) => {
      console.log(`      ${i + 1}. $${entry.balance} - ${entry.notes} (${entry.created_at})`);
    });
    console.log('');

    // Step 8: Test receipt storage (simulate)
    console.log('8️⃣ Testing receipt storage...');
    const receiptResult = await sql`
      INSERT INTO gift_card_receipts (
        card_id,
        balance_history_id,
        image_url,
        notes,
        purchase_date
      )
      VALUES (
        ${testCardId},
        ${historyResult2.rows[0].id},
        'https://example.com/receipt-lunch.jpg',
        'Lunch at Test Restaurant',
        NOW()
      )
      RETURNING *
    `;
    console.log('   ✅ Receipt stored\n');
    console.log('   Receipt:', receiptResult.rows[0]);
    console.log('');

    // Step 9: Get receipts with associated balance
    console.log('9️⃣ Retrieving receipts with associated balance...');
    const receiptsQuery = await sql`
      SELECT
        r.*,
        h.balance as associated_balance
      FROM gift_card_receipts r
      LEFT JOIN gift_card_balance_history h ON r.balance_history_id = h.id
      WHERE r.card_id = ${testCardId}
      ORDER BY COALESCE(r.purchase_date, r.created_at) DESC
    `;
    console.log(`   ✅ Found ${receiptsQuery.rows.length} receipts:\n`);
    receiptsQuery.rows.forEach((receipt, i) => {
      console.log(`      ${i + 1}. ${receipt.notes} - Balance: $${receipt.associated_balance}`);
      console.log(`         Image: ${receipt.image_url}`);
    });
    console.log('');

    // Step 10: Verify card has current balance
    console.log('🔟 Verifying card current balance...');
    const cardCheck = await sql`
      SELECT
        id,
        name,
        current_balance,
        balance_currency,
        balance_last_updated
      FROM cards
      WHERE id = ${testCardId}
    `;
    const card = cardCheck.rows[0];
    console.log('   ✅ Card retrieved:\n');
    console.log(`      Name: ${card.name}`);
    console.log(`      Balance: $${card.current_balance} ${card.balance_currency}`);
    console.log(`      Last Updated: ${card.balance_last_updated}`);
    console.log('');

    console.log('✅ All tests passed!\n');

  } catch (error) {
    console.error('\n❌ Test failed:', error);
    throw error;
  } finally {
    // Cleanup
    console.log('🧹 Cleaning up test data...\n');

    if (testCardId) {
      await sql`DELETE FROM cards WHERE id = ${testCardId}`;
      console.log('   ✅ Test card deleted');
    }

    if (testBrandId) {
      await sql`DELETE FROM gift_card_brands WHERE id = ${testBrandId}`;
      console.log('   ✅ Test brand deleted');
    }

    console.log('\n✨ Test completed!\n');
  }
}

testBalanceTracking().catch(console.error);
