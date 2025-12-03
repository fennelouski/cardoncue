import { NextRequest, NextResponse } from 'next/server';
import { pool } from '@/lib/db';
import { requireAdminAuth } from '@/lib/adminAuth';

export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string; locationId: string } }
) {
  try {
    await requireAdminAuth();

    const { id: templateId, locationId } = params;

    const result = await pool.query(
      'DELETE FROM template_brand_locations WHERE template_id = $1 AND brand_location_id = $2 RETURNING id',
      [templateId, locationId]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Association not found' },
        { status: 404 }
      );
    }

    return NextResponse.json({
      message: 'Location association removed successfully',
      id: result.rows[0].id,
    });
  } catch (error: any) {
    console.error('DELETE /admin/card-templates/[id]/locations/[locationId] error:', error);

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

export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string; locationId: string } }
) {
  try {
    await requireAdminAuth();

    const { id: templateId, locationId } = params;
    const body = await request.json();
    const { priority } = body;

    if (priority === undefined) {
      return NextResponse.json(
        { error: 'Priority is required' },
        { status: 400 }
      );
    }

    const result = await pool.query(
      `
      UPDATE template_brand_locations
      SET priority = $1
      WHERE template_id = $2 AND brand_location_id = $3
      RETURNING *
      `,
      [priority, templateId, locationId]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Association not found' },
        { status: 404 }
      );
    }

    return NextResponse.json({
      id: result.rows[0].id,
      templateId: result.rows[0].template_id,
      locationId: result.rows[0].brand_location_id,
      priority: result.rows[0].priority,
      createdAt: result.rows[0].created_at,
    });
  } catch (error: any) {
    console.error('PATCH /admin/card-templates/[id]/locations/[locationId] error:', error);

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
