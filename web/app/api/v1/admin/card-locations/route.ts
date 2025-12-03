import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';

const ALLOWED_ADMIN_DOMAIN = '@100apps.studio';

/**
 * Check if the provided email is from an authorized admin domain
 */
function isAuthorizedAdmin(email: string): boolean {
  return email.toLowerCase().endsWith(ALLOWED_ADMIN_DOMAIN);
}

/**
 * GET /api/v1/admin/card-locations
 * Get all card locations (admin only - requires @100apps.studio email)
 * Query params:
 *   - email: Required. Must end with @100apps.studio
 *   - limit: Optional. Number of results to return (default: 100)
 *   - offset: Optional. Number of results to skip (default: 0)
 */
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const email = searchParams.get('email');
    const limit = parseInt(searchParams.get('limit') || '100');
    const offset = parseInt(searchParams.get('offset') || '0');

    // Check for required email parameter
    if (!email) {
      return NextResponse.json(
        { error: 'Email parameter is required' },
        { status: 400 }
      );
    }

    // Verify email is from authorized admin domain
    if (!isAuthorizedAdmin(email)) {
      return NextResponse.json(
        {
          error: 'Unauthorized',
          message: `Access restricted to ${ALLOWED_ADMIN_DOMAIN} email addresses`,
        },
        { status: 403 }
      );
    }

    // Fetch all card locations with card names (but not sensitive data like payload/barcode)
    const result = await sql`
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
        cl.created_at,
        cl.updated_at
      FROM card_locations cl
      INNER JOIN cards c ON cl.card_id = c.id
      ORDER BY cl.created_at DESC
      LIMIT ${limit}
      OFFSET ${offset}
    `;

    // Get total count for pagination
    const countResult = await sql`
      SELECT COUNT(*) as total
      FROM card_locations
    `;

    const total = parseInt(countResult.rows[0].total);

    return NextResponse.json({
      success: true,
      locations: result.rows,
      pagination: {
        total,
        limit,
        offset,
        hasMore: offset + limit < total,
      },
      admin: {
        email,
        accessGranted: true,
      },
    });
  } catch (error) {
    console.error('Error fetching card locations for admin:', error);
    return NextResponse.json(
      { error: 'Failed to fetch card locations' },
      { status: 500 }
    );
  }
}
