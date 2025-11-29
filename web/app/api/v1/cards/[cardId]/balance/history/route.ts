import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';

/**
 * GET /api/v1/cards/[cardId]/balance/history
 * Get balance history for a card
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

    // Get URL params for pagination
    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get('limit') || '50');
    const offset = parseInt(searchParams.get('offset') || '0');

    // Verify card exists
    const cardCheck = await sql`
      SELECT id FROM cards WHERE id = ${cardId}
    `;

    if (cardCheck.rows.length === 0) {
      return NextResponse.json({ error: 'Card not found' }, { status: 404 });
    }

    // Get balance history
    const result = await sql`
      SELECT
        id,
        card_id,
        balance,
        currency,
        notes,
        created_at
      FROM gift_card_balance_history
      WHERE card_id = ${cardId}
      ORDER BY created_at DESC
      LIMIT ${limit}
      OFFSET ${offset}
    `;

    // Get total count
    const countResult = await sql`
      SELECT COUNT(*) as total
      FROM gift_card_balance_history
      WHERE card_id = ${cardId}
    `;

    const total = parseInt(countResult.rows[0].total);

    return NextResponse.json({
      cardId,
      history: result.rows,
      pagination: {
        limit,
        offset,
        total,
        hasMore: offset + limit < total,
      },
      success: true,
    });
  } catch (error) {
    console.error('Error fetching balance history:', error);
    return NextResponse.json(
      { error: 'Failed to fetch balance history' },
      { status: 500 }
    );
  }
}
