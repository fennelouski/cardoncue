import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';

/**
 * POST /api/v1/cards/[cardId]/balance
 * Update card balance and create history entry
 */
export async function POST(
  request: NextRequest,
  { params }: { params: { cardId: string } }
) {
  try {
    const { cardId } = params;

    if (!cardId) {
      return NextResponse.json({ error: 'Card ID is required' }, { status: 400 });
    }

    const body = await request.json();
    const { balance, currency = 'USD', notes } = body;

    if (balance === undefined || balance === null) {
      return NextResponse.json({ error: 'Balance is required' }, { status: 400 });
    }

    // Validate balance is a number
    const balanceNum = parseFloat(balance);
    if (isNaN(balanceNum)) {
      return NextResponse.json({ error: 'Balance must be a valid number' }, { status: 400 });
    }

    // Verify card exists
    const cardCheck = await sql`
      SELECT id FROM cards WHERE id = ${cardId}
    `;

    if (cardCheck.rows.length === 0) {
      return NextResponse.json({ error: 'Card not found' }, { status: 404 });
    }

    // Update card's current balance
    await sql`
      UPDATE cards
      SET
        current_balance = ${balanceNum},
        balance_currency = ${currency},
        balance_last_updated = NOW(),
        updated_at = NOW()
      WHERE id = ${cardId}
    `;

    // Create history entry
    const historyResult = await sql`
      INSERT INTO gift_card_balance_history (card_id, balance, currency, notes)
      VALUES (${cardId}, ${balanceNum}, ${currency}, ${notes || null})
      RETURNING id, card_id, balance, currency, notes, created_at
    `;

    const historyEntry = historyResult.rows[0];

    return NextResponse.json({
      cardId,
      balance: balanceNum,
      currency,
      historyEntry,
      success: true,
    });
  } catch (error) {
    console.error('Error updating card balance:', error);
    return NextResponse.json(
      { error: 'Failed to update card balance' },
      { status: 500 }
    );
  }
}

/**
 * GET /api/v1/cards/[cardId]/balance
 * Get current balance for a card
 */
export async function GET(
  request: NextRequest,
  { params }: { params: { cardId: string } }
) {
  try {
    const { cardId } = params;

    if (!cardId) {
      return NextResponse.json({ error: 'Card ID is required' }, { status: 400 });
    }

    const result = await sql`
      SELECT
        id,
        current_balance,
        balance_currency,
        balance_last_updated
      FROM cards
      WHERE id = ${cardId}
    `;

    if (result.rows.length === 0) {
      return NextResponse.json({ error: 'Card not found' }, { status: 404 });
    }

    const card = result.rows[0];

    return NextResponse.json({
      cardId,
      balance: card.current_balance,
      currency: card.balance_currency,
      lastUpdated: card.balance_last_updated,
      success: true,
    });
  } catch (error) {
    console.error('Error fetching card balance:', error);
    return NextResponse.json(
      { error: 'Failed to fetch card balance' },
      { status: 500 }
    );
  }
}
