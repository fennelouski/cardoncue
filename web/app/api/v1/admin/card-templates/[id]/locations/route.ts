import { NextRequest, NextResponse } from 'next/server';
import { pool } from '@/lib/db';
import { requireAdminAuth } from '@/lib/adminAuth';

export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    await requireAdminAuth();

    const { id: templateId } = params;
    const body = await request.json();
    const { locationId, priority = 0 } = body;

    if (!locationId) {
      return NextResponse.json(
        { error: 'Location ID is required' },
        { status: 400 }
      );
    }

    // Check if template exists
    const templateCheck = await pool.query(
      'SELECT id FROM card_templates WHERE id = $1',
      [templateId]
    );

    if (templateCheck.rows.length === 0) {
      return NextResponse.json(
        { error: 'Template not found' },
        { status: 404 }
      );
    }

    // Check if location exists
    const locationCheck = await pool.query(
      'SELECT id FROM brand_locations WHERE id = $1',
      [locationId]
    );

    if (locationCheck.rows.length === 0) {
      return NextResponse.json(
        { error: 'Location not found' },
        { status: 404 }
      );
    }

    // Create association (will fail if already exists due to unique constraint)
    const result = await pool.query(
      `
      INSERT INTO template_brand_locations (template_id, brand_location_id, priority)
      VALUES ($1, $2, $3)
      ON CONFLICT (template_id, brand_location_id)
      DO UPDATE SET priority = $3
      RETURNING *
      `,
      [templateId, locationId, priority]
    );

    return NextResponse.json({
      id: result.rows[0].id,
      templateId: result.rows[0].template_id,
      locationId: result.rows[0].brand_location_id,
      priority: result.rows[0].priority,
      createdAt: result.rows[0].created_at,
    }, { status: 201 });
  } catch (error: any) {
    console.error('POST /admin/card-templates/[id]/locations error:', error);

    if (error.message?.includes('Unauthorized') || error.message?.includes('Forbidden')) {
      return NextResponse.json(
        { error: error.message },
        { status: 403 }
      );
    }

    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    await requireAdminAuth();

    const { id: templateId } = params;

    const result = await pool.query(
      `
      SELECT
        tl.*,
        l.name,
        l.address,
        l.city,
        l.state,
        l.latitude,
        l.longitude
      FROM template_brand_locations tl
      JOIN brand_locations l ON tl.brand_location_id = l.id
      WHERE tl.template_id = $1
      ORDER BY tl.priority ASC, l.name ASC
      `,
      [templateId]
    );

    const locations = result.rows.map(row => ({
      id: row.id,
      locationId: row.brand_location_id,
      name: row.name,
      address: row.address,
      city: row.city,
      state: row.state,
      latitude: row.latitude ? parseFloat(row.latitude) : null,
      longitude: row.longitude ? parseFloat(row.longitude) : null,
      priority: row.priority,
      createdAt: row.created_at,
    }));

    return NextResponse.json({ locations });
  } catch (error: any) {
    console.error('GET /admin/card-templates/[id]/locations error:', error);

    if (error.message?.includes('Unauthorized') || error.message?.includes('Forbidden')) {
      return NextResponse.json(
        { error: error.message },
        { status: 403 }
      );
    }

    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
