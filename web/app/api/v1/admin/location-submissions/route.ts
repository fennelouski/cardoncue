import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';
import { requireAdminAuth } from '@/lib/adminAuth';

export const dynamic = 'force-dynamic';

function mapRow(row: Record<string, unknown>) {
  const networkIds = row.network_ids;
  let networkIdsList: string[] = [];
  if (Array.isArray(networkIds)) {
    networkIdsList = networkIds as string[];
  } else if (typeof networkIds === 'string') {
    try {
      const parsed = JSON.parse(networkIds);
      if (Array.isArray(parsed)) networkIdsList = parsed;
    } catch {
      // ignore
    }
  }

  return {
    id: row.id,
    cardId: row.card_id,
    cardName: row.card_name,
    cardType: row.card_type,
    networkIds: networkIdsList,
    userId: row.user_id,
    locationName: row.location_name,
    address: row.address,
    city: row.city,
    state: row.state,
    country: row.country,
    postalCode: row.postal_code,
    latitude: row.latitude != null ? Number(row.latitude) : null,
    longitude: row.longitude != null ? Number(row.longitude) : null,
    notes: row.notes,
    status: row.status,
    source: row.source,
    suggestedNetworkId: row.suggested_network_id,
    reportCount: row.report_count != null ? Number(row.report_count) : 1,
    reviewedAt: row.reviewed_at,
    reviewedBy: row.reviewed_by,
    rejectionReason: row.rejection_reason,
    approvedCuratedKey: row.approved_curated_key,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/**
 * GET /api/v1/admin/location-submissions
 */
export async function GET(request: NextRequest) {
  try {
    await requireAdminAuth();

    const { searchParams } = new URL(request.url);
    const status = searchParams.get('status') || 'pending';
    const search = searchParams.get('search') || '';
    const networkId = searchParams.get('networkId') || '';
    const limit = Math.min(parseInt(searchParams.get('limit') || '50', 10), 200);
    const offset = parseInt(searchParams.get('offset') || '0', 10);

    let query = `
      SELECT
        cl.*,
        c.name as card_name,
        c.card_type,
        c.network_ids
      FROM card_locations cl
      INNER JOIN cards c ON cl.card_id = c.id
      WHERE 1=1
    `;

    const params: (string | number)[] = [];
    let paramIndex = 0;

    if (status && status !== 'all') {
      paramIndex++;
      query += ` AND cl.status = $${paramIndex}`;
      params.push(status);
    }

    if (search) {
      paramIndex++;
      query += ` AND (
        cl.location_name ILIKE $${paramIndex}
        OR c.name ILIKE $${paramIndex}
        OR cl.address ILIKE $${paramIndex}
      )`;
      params.push(`%${search}%`);
    }

    if (networkId) {
      paramIndex++;
      query += ` AND (
        cl.suggested_network_id = $${paramIndex}
        OR $${paramIndex} = ANY(c.network_ids)
      )`;
      params.push(networkId);
    }

    query += ` ORDER BY cl.report_count DESC, cl.created_at DESC`;
    paramIndex++;
    query += ` LIMIT $${paramIndex}`;
    params.push(limit);
    paramIndex++;
    query += ` OFFSET $${paramIndex}`;
    params.push(offset);

    const result = await sql.query(query, params);

    let countQuery = `
      SELECT COUNT(*)::int as total
      FROM card_locations cl
      INNER JOIN cards c ON cl.card_id = c.id
      WHERE 1=1
    `;
    const countParams: (string | number)[] = [];
    let countIndex = 0;

    if (status && status !== 'all') {
      countIndex++;
      countQuery += ` AND cl.status = $${countIndex}`;
      countParams.push(status);
    }

    if (search) {
      countIndex++;
      countQuery += ` AND (
        cl.location_name ILIKE $${countIndex}
        OR c.name ILIKE $${countIndex}
        OR cl.address ILIKE $${countIndex}
      )`;
      countParams.push(`%${search}%`);
    }

    if (networkId) {
      countIndex++;
      countQuery += ` AND (
        cl.suggested_network_id = $${countIndex}
        OR $${countIndex} = ANY(c.network_ids)
      )`;
      countParams.push(networkId);
    }

    const countResult = await sql.query(countQuery, countParams);
    const total = countResult.rows[0]?.total ?? 0;

    return NextResponse.json({
      success: true,
      submissions: result.rows.map((row) => mapRow(row)),
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
    console.error('GET location-submissions error:', error);
    return NextResponse.json({ error: 'Failed to fetch submissions' }, { status: 500 });
  }
}
