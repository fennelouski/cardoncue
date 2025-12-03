import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';

/**
 * POST /api/v1/cards/[cardId]/locations
 * Add a new location for a card
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
    const {
      userId,
      locationName,
      address,
      city,
      state,
      country,
      postalCode,
      latitude,
      longitude,
      notes,
    } = body;

    if (!userId) {
      return NextResponse.json({ error: 'User ID is required' }, { status: 400 });
    }

    if (!locationName) {
      return NextResponse.json({ error: 'Location name is required' }, { status: 400 });
    }

    // Verify card exists and belongs to user
    const cardCheck = await sql`
      SELECT id, user_id FROM cards WHERE id = ${cardId}
    `;

    if (cardCheck.rows.length === 0) {
      return NextResponse.json({ error: 'Card not found' }, { status: 404 });
    }

    const card = cardCheck.rows[0];
    if (card.user_id !== userId) {
      return NextResponse.json(
        { error: 'Unauthorized: Card does not belong to this user' },
        { status: 403 }
      );
    }

    // Insert location
    const result = await sql`
      INSERT INTO card_locations (
        card_id,
        user_id,
        location_name,
        address,
        city,
        state,
        country,
        postal_code,
        latitude,
        longitude,
        notes
      )
      VALUES (
        ${cardId},
        ${userId},
        ${locationName},
        ${address || null},
        ${city || null},
        ${state || null},
        ${country || null},
        ${postalCode || null},
        ${latitude || null},
        ${longitude || null},
        ${notes || null}
      )
      RETURNING
        id,
        card_id,
        user_id,
        location_name,
        address,
        city,
        state,
        country,
        postal_code,
        latitude,
        longitude,
        notes,
        created_at,
        updated_at
    `;

    const location = result.rows[0];

    return NextResponse.json({
      success: true,
      location,
    }, { status: 201 });
  } catch (error) {
    console.error('Error adding card location:', error);
    return NextResponse.json(
      { error: 'Failed to add card location' },
      { status: 500 }
    );
  }
}

/**
 * GET /api/v1/cards/[cardId]/locations
 * Get all locations for a card
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

    // Get userId from query params for authorization
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');

    if (!userId) {
      return NextResponse.json({ error: 'User ID is required' }, { status: 400 });
    }

    // Verify card exists and belongs to user
    const cardCheck = await sql`
      SELECT id, user_id FROM cards WHERE id = ${cardId}
    `;

    if (cardCheck.rows.length === 0) {
      return NextResponse.json({ error: 'Card not found' }, { status: 404 });
    }

    const card = cardCheck.rows[0];
    if (card.user_id !== userId) {
      return NextResponse.json(
        { error: 'Unauthorized: Card does not belong to this user' },
        { status: 403 }
      );
    }

    // Get locations for this card
    const result = await sql`
      SELECT
        id,
        card_id,
        location_name,
        address,
        city,
        state,
        country,
        postal_code,
        latitude,
        longitude,
        notes,
        created_at,
        updated_at
      FROM card_locations
      WHERE card_id = ${cardId}
      ORDER BY created_at DESC
    `;

    return NextResponse.json({
      success: true,
      locations: result.rows,
    });
  } catch (error) {
    console.error('Error fetching card locations:', error);
    return NextResponse.json(
      { error: 'Failed to fetch card locations' },
      { status: 500 }
    );
  }
}
