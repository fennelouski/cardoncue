import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';
import { requireJwtAuth } from '@/lib/jwtAuth';

/**
 * GET /api/v1/cards/[cardId]/balance/history
 * Get balance history for a card
 */
export async function GET(
  request: NextRequest,
  { params }: { params: { cardId: string } }
) {
  try {
    const user = await requireJwtAuth(request);
    const { cardId } = params;

    if (!cardId) {
      return NextResponse.json({ error: 'Card ID is required' }, { status: 400 });
    }

    // Get URL params for pagination
    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get('limit') || '50');
    const offset = parseInt(searchParams.get('offset') || '0');

    // Verify the card exists and belongs to the authenticated user
    const cardCheck = await sql`
      SELECT id, user_id FROM cards WHERE id = ${cardId}
    `;

    if (cardCheck.rows.length === 0) {
      return NextResponse.json({ error: 'Card not found' }, { status: 404 });
    }

    if (cardCheck.rows[0].user_id !== user.id) {
      return NextResponse.json(
        { error: 'Unauthorized: Card does not belong to this user' },
        { status: 403 }
      );
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
    const message = error instanceof Error ? error.message : '';
    if (message.includes('Unauthorized')) {
      return NextResponse.json({ error: message }, { status: 401 });
    }
    console.error('Error fetching balance history:', error);
    return NextResponse.json(
      { error: 'Failed to fetch balance history' },
      { status: 500 }
    );
  }
}
