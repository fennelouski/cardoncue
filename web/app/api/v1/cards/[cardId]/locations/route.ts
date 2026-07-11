import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';
import { requireJwtAuth } from '@/lib/jwtAuth';
import {
  firstNetworkId,
  findDuplicateSubmission,
  type NearbySubmissionRow,
  type SubmissionSource,
} from '@/lib/locationSubmissions';

export const dynamic = 'force-dynamic';

const VALID_SOURCES: SubmissionSource[] = ['add_place', 'manual_entry', 'card_location'];

/**
 * POST /api/v1/cards/[cardId]/locations
 * Submit a user-reported location (JWT auth, pending queue).
 */
export async function POST(
  request: NextRequest,
  { params }: { params: { cardId: string } }
) {
  try {
    const user = await requireJwtAuth(request);
    const { cardId } = params;

    if (!cardId) {
      return NextResponse.json({ error: 'Card ID is required' }, { status: 400 });
    }

    const body = await request.json();
    const {
      address,
      city,
      state,
      country,
      latitude,
      longitude,
      notes,
      source = 'add_place',
    } = body;
    // iOS sends snake_case (APIClient uses .convertToSnakeCase); accept both casings.
    const locationName = body.locationName ?? body.location_name;
    const postalCode = body.postalCode ?? body.postal_code;

    if (!locationName) {
      return NextResponse.json({ error: 'Location name is required' }, { status: 400 });
    }

    if (!VALID_SOURCES.includes(source)) {
      return NextResponse.json({ error: 'Invalid source' }, { status: 400 });
    }

    const cardCheck = await sql`
      SELECT id, user_id, network_ids, metadata
      FROM cards
      WHERE id = ${cardId}
    `;

    if (cardCheck.rows.length === 0) {
      return NextResponse.json({ error: 'Card not found' }, { status: 404 });
    }

    const card = cardCheck.rows[0];
    if (card.user_id !== user.id) {
      return NextResponse.json(
        { error: 'Unauthorized: Card does not belong to this user' },
        { status: 403 }
      );
    }

    const metadata =
      typeof card.metadata === 'string'
        ? JSON.parse(card.metadata)
        : card.metadata ?? {};

    const suggestedNetworkId = firstNetworkId(card.network_ids, metadata);

    const lat = latitude != null ? Number(latitude) : null;
    const lon = longitude != null ? Number(longitude) : null;

    if (lat != null && lon != null && !Number.isNaN(lat) && !Number.isNaN(lon)) {
      const candidates = await sql`
        SELECT id, latitude, longitude, suggested_network_id, report_count, status
        FROM card_locations
        WHERE card_id = ${cardId}
          AND status IN ('pending', 'approved')
          AND latitude IS NOT NULL
          AND longitude IS NOT NULL
      `;

      const duplicate = findDuplicateSubmission(
        candidates.rows as NearbySubmissionRow[],
        lat,
        lon,
        suggestedNetworkId
      );

      if (duplicate) {
        const updated = await sql`
          UPDATE card_locations
          SET report_count = report_count + 1,
              updated_at = NOW()
          WHERE id = ${duplicate.id}
          RETURNING
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
            status,
            source,
            suggested_network_id,
            report_count,
            created_at,
            updated_at
        `;

        return NextResponse.json({
          success: true,
          duplicate: true,
          location: updated.rows[0],
        });
      }
    }

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
        notes,
        status,
        source,
        suggested_network_id,
        report_count
      )
      VALUES (
        ${cardId},
        ${user.id},
        ${locationName},
        ${address || null},
        ${city || null},
        ${state || null},
        ${country || null},
        ${postalCode || null},
        ${latitude ?? null},
        ${longitude ?? null},
        ${notes || null},
        'pending',
        ${source},
        ${suggestedNetworkId},
        1
      )
      RETURNING
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
        status,
        source,
        suggested_network_id,
        report_count,
        created_at,
        updated_at
    `;

    return NextResponse.json(
      {
        success: true,
        duplicate: false,
        location: result.rows[0],
      },
      { status: 201 }
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    if (message.includes('Unauthorized')) {
      return NextResponse.json({ error: message }, { status: 401 });
    }
    console.error('Error adding card location:', error);
    return NextResponse.json(
      { error: 'Failed to add card location' },
      { status: 500 }
    );
  }
}

/**
 * GET /api/v1/cards/[cardId]/locations
 * Get all locations for a card (JWT auth).
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
        status,
        source,
        suggested_network_id,
        report_count,
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
    const message = error instanceof Error ? error.message : 'Unknown error';
    if (message.includes('Unauthorized')) {
      return NextResponse.json({ error: message }, { status: 401 });
    }
    console.error('Error fetching card locations:', error);
    return NextResponse.json(
      { error: 'Failed to fetch card locations' },
      { status: 500 }
    );
  }
}
