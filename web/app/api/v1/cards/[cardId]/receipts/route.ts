import { NextRequest, NextResponse } from 'next/server';
import { put, del } from '@vercel/blob';
import { sql } from '@vercel/postgres';

/**
 * POST /api/v1/cards/[cardId]/receipts
 * Upload a receipt image for a card
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

    const formData = await request.formData();
    const file = formData.get('receipt') as File;
    const notes = formData.get('notes') as string | null;
    const purchaseDate = formData.get('purchaseDate') as string | null;
    const balanceHistoryId = formData.get('balanceHistoryId') as string | null;

    if (!file) {
      return NextResponse.json({ error: 'Receipt file is required' }, { status: 400 });
    }

    // Validate file type
    if (!file.type.startsWith('image/')) {
      return NextResponse.json({ error: 'File must be an image' }, { status: 400 });
    }

    // Validate file size (max 10MB for receipts)
    if (file.size > 10 * 1024 * 1024) {
      return NextResponse.json({ error: 'File size must be less than 10MB' }, { status: 400 });
    }

    // Verify card exists
    const cardCheck = await sql`
      SELECT id FROM cards WHERE id = ${cardId}
    `;

    if (cardCheck.rows.length === 0) {
      return NextResponse.json({ error: 'Card not found' }, { status: 404 });
    }

    // Upload to Vercel Blob
    const blob = await put(`gift-card-receipts/${cardId}/${file.name}`, file, {
      access: 'public',
      addRandomSuffix: true,
    });

    // Store receipt in database
    const result = await sql`
      INSERT INTO gift_card_receipts
        (card_id, balance_history_id, image_url, notes, purchase_date)
      VALUES
        (${cardId}, ${balanceHistoryId}, ${blob.url}, ${notes}, ${purchaseDate})
      RETURNING id, card_id, balance_history_id, image_url, notes, purchase_date, created_at
    `;

    const receipt = result.rows[0];

    return NextResponse.json({
      cardId,
      receipt,
      success: true,
    });
  } catch (error) {
    console.error('Error uploading receipt:', error);
    return NextResponse.json(
      { error: 'Failed to upload receipt' },
      { status: 500 }
    );
  }
}

/**
 * GET /api/v1/cards/[cardId]/receipts
 * Get all receipts for a card
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

    // Get receipts
    const result = await sql`
      SELECT
        r.id,
        r.card_id,
        r.balance_history_id,
        r.image_url,
        r.notes,
        r.purchase_date,
        r.created_at,
        h.balance as associated_balance
      FROM gift_card_receipts r
      LEFT JOIN gift_card_balance_history h ON r.balance_history_id = h.id
      WHERE r.card_id = ${cardId}
      ORDER BY COALESCE(r.purchase_date, r.created_at) DESC
      LIMIT ${limit}
      OFFSET ${offset}
    `;

    // Get total count
    const countResult = await sql`
      SELECT COUNT(*) as total
      FROM gift_card_receipts
      WHERE card_id = ${cardId}
    `;

    const total = parseInt(countResult.rows[0].total);

    return NextResponse.json({
      cardId,
      receipts: result.rows,
      pagination: {
        limit,
        offset,
        total,
        hasMore: offset + limit < total,
      },
      success: true,
    });
  } catch (error) {
    console.error('Error fetching receipts:', error);
    return NextResponse.json(
      { error: 'Failed to fetch receipts' },
      { status: 500 }
    );
  }
}
