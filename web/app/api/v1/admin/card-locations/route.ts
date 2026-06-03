import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';
import { requireAdminAuth } from '@/lib/adminAuth';

export const dynamic = 'force-dynamic';

/**
 * GET /api/v1/admin/card-locations
 * Legacy alias — prefer /api/v1/admin/location-submissions
 */
export async function GET(request: NextRequest) {
  try {
    await requireAdminAuth();

    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get('limit') || '100', 10);
    const offset = parseInt(searchParams.get('offset') || '0', 10);
    const status = searchParams.get('status') || 'all';

    const result =
      status !== 'all'
        ? await sql`
            SELECT
              cl.id,
              cl.card_id,
              c.name as card_name,
              c.card_type,
              cl.location_name,
              cl.address,
              cl.city,
              cl.state,
              cl.country,
              cl.postal_code,
              cl.latitude,
              cl.longitude,
              cl.notes,
              cl.status,
              cl.source,
              cl.suggested_network_id,
              cl.report_count,
              cl.created_at,
              cl.updated_at
            FROM card_locations cl
            INNER JOIN cards c ON cl.card_id = c.id
            WHERE cl.status = ${status}
            ORDER BY cl.created_at DESC
            LIMIT ${limit}
            OFFSET ${offset}
          `
        : await sql`
            SELECT
              cl.id,
              cl.card_id,
              c.name as card_name,
              c.card_type,
              cl.location_name,
              cl.address,
              cl.city,
              cl.state,
              cl.country,
              cl.postal_code,
              cl.latitude,
              cl.longitude,
              cl.notes,
              cl.status,
              cl.source,
              cl.suggested_network_id,
              cl.report_count,
              cl.created_at,
              cl.updated_at
            FROM card_locations cl
            INNER JOIN cards c ON cl.card_id = c.id
            ORDER BY cl.created_at DESC
            LIMIT ${limit}
            OFFSET ${offset}
          `;

    const countResult =
      status !== 'all'
        ? await sql`
            SELECT COUNT(*)::int as total
            FROM card_locations
            WHERE status = ${status}
          `
        : await sql`
            SELECT COUNT(*)::int as total
            FROM card_locations
          `;

    const total = countResult.rows[0]?.total ?? 0;

    return NextResponse.json({
      success: true,
      locations: result.rows,
      pagination: {
        total: Number(total),
        limit,
        offset,
        hasMore: offset + limit < Number(total),
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    if (message.includes('Unauthorized') || message.includes('Forbidden')) {
      return NextResponse.json({ error: message }, { status: 403 });
    }
    console.error('Error fetching card locations for admin:', error);
    return NextResponse.json(
      { error: 'Failed to fetch card locations' },
      { status: 500 }
    );
  }
}
