import { NextRequest, NextResponse } from 'next/server';
import { pool } from '@/lib/db';
import { requireAdminAuth } from '@/lib/adminAuth';

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    await requireAdminAuth();

    const { id } = params;

    const result = await pool.query(
      `
      SELECT
        l.*,
        b.name as brand_name,
        b.display_name as brand_display_name,
        json_agg(
          DISTINCT jsonb_build_object(
            'id', tl.template_id,
            'cardName', ct.card_name,
            'priority', tl.priority
          )
        ) FILTER (WHERE tl.template_id IS NOT NULL) as templates
      FROM brand_locations l
      LEFT JOIN brands b ON l.brand_id = b.id
      LEFT JOIN template_brand_locations tl ON l.id = tl.brand_location_id
      LEFT JOIN card_templates ct ON tl.template_id = ct.id
      WHERE l.id = $1
      GROUP BY l.id, b.id
      `,
      [id]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Location not found' },
        { status: 404 }
      );
    }

    const location = result.rows[0];

    return NextResponse.json({
      id: location.id,
      brandId: location.brand_id,
      brandName: location.brand_name,
      brandDisplayName: location.brand_display_name,
      name: location.name,
      address: location.address,
      city: location.city,
      state: location.state,
      zipCode: location.zip_code,
      country: location.country,
      latitude: location.latitude ? parseFloat(location.latitude) : null,
      longitude: location.longitude ? parseFloat(location.longitude) : null,
      phone: location.phone,
      email: location.email,
      website: location.website,
      regularHours: location.regular_hours,
      specialHours: location.special_hours,
      timezone: location.timezone,
      placeId: location.place_id,
      verified: location.verified,
      notes: location.notes,
      templates: location.templates || [],
      createdAt: location.created_at,
      updatedAt: location.updated_at,
    });
  } catch (error: any) {
    console.error('GET /admin/locations/[id] error:', error);

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
  { params }: { params: { id: string } }
) {
  try {
    await requireAdminAuth();

    const { id } = params;
    const body = await request.json();

    const {
      brandId,
      name,
      address,
      city,
      state,
      zipCode,
      country,
      latitude,
      longitude,
      phone,
      email,
      website,
      regularHours,
      specialHours,
      timezone,
      placeId,
      verified,
      notes,
    } = body;

    const updates: string[] = [];
    const values: any[] = [];
    let paramCount = 0;

    if (brandId !== undefined) {
      paramCount++;
      updates.push(`brand_id = $${paramCount}`);
      values.push(brandId || null);
    }

    if (name !== undefined) {
      paramCount++;
      updates.push(`name = $${paramCount}`);
      values.push(name.trim());
    }

    if (address !== undefined) {
      paramCount++;
      updates.push(`address = $${paramCount}`);
      values.push(address.trim());
    }

    if (city !== undefined) {
      paramCount++;
      updates.push(`city = $${paramCount}`);
      values.push(city?.trim() || null);
    }

    if (state !== undefined) {
      paramCount++;
      updates.push(`state = $${paramCount}`);
      values.push(state?.trim() || null);
    }

    if (zipCode !== undefined) {
      paramCount++;
      updates.push(`zip_code = $${paramCount}`);
      values.push(zipCode?.trim() || null);
    }

    if (country !== undefined) {
      paramCount++;
      updates.push(`country = $${paramCount}`);
      values.push(country);
    }

    if (latitude !== undefined) {
      if (latitude < -90 || latitude > 90) {
        return NextResponse.json(
          { error: 'Invalid latitude' },
          { status: 400 }
        );
      }
      paramCount++;
      updates.push(`latitude = $${paramCount}`);
      values.push(latitude);
    }

    if (longitude !== undefined) {
      if (longitude < -180 || longitude > 180) {
        return NextResponse.json(
          { error: 'Invalid longitude' },
          { status: 400 }
        );
      }
      paramCount++;
      updates.push(`longitude = $${paramCount}`);
      values.push(longitude);
    }

    if (phone !== undefined) {
      paramCount++;
      updates.push(`phone = $${paramCount}`);
      values.push(phone || null);
    }

    if (email !== undefined) {
      paramCount++;
      updates.push(`email = $${paramCount}`);
      values.push(email || null);
    }

    if (website !== undefined) {
      paramCount++;
      updates.push(`website = $${paramCount}`);
      values.push(website || null);
    }

    if (regularHours !== undefined) {
      paramCount++;
      updates.push(`regular_hours = $${paramCount}`);
      values.push(regularHours ? JSON.stringify(regularHours) : null);
    }

    if (specialHours !== undefined) {
      paramCount++;
      updates.push(`special_hours = $${paramCount}`);
      values.push(specialHours ? JSON.stringify(specialHours) : null);
    }

    if (timezone !== undefined) {
      paramCount++;
      updates.push(`timezone = $${paramCount}`);
      values.push(timezone);
    }

    if (placeId !== undefined) {
      paramCount++;
      updates.push(`place_id = $${paramCount}`);
      values.push(placeId || null);
    }

    if (verified !== undefined) {
      paramCount++;
      updates.push(`verified = $${paramCount}`);
      values.push(verified);
    }

    if (notes !== undefined) {
      paramCount++;
      updates.push(`notes = $${paramCount}`);
      values.push(notes || null);
    }

    if (updates.length === 0) {
      return NextResponse.json(
        { error: 'No fields to update' },
        { status: 400 }
      );
    }

    values.push(id);
    const result = await pool.query(
      `
      UPDATE brand_locations
      SET ${updates.join(', ')}
      WHERE id = $${paramCount + 1}
      RETURNING *
      `,
      values
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Location not found' },
        { status: 404 }
      );
    }

    const location = result.rows[0];

    return NextResponse.json({
      id: location.id,
      brandId: location.brand_id,
      name: location.name,
      address: location.address,
      city: location.city,
      state: location.state,
      zipCode: location.zip_code,
      country: location.country,
      latitude: parseFloat(location.latitude),
      longitude: parseFloat(location.longitude),
      phone: location.phone,
      email: location.email,
      website: location.website,
      regularHours: location.regular_hours,
      specialHours: location.special_hours,
      timezone: location.timezone,
      placeId: location.place_id,
      verified: location.verified,
      notes: location.notes,
      createdAt: location.created_at,
      updatedAt: location.updated_at,
    });
  } catch (error: any) {
    console.error('PATCH /admin/locations/[id] error:', error);

    if (error.message?.includes('Unauthorized') || error.message?.includes('Forbidden')) {
      return NextResponse.json(
        { error: error.message },
        { status: 403 }
      );
    }

    if (error.code === '23503') {
      return NextResponse.json(
        { error: 'Invalid brand ID' },
        { status: 400 }
      );
    }

    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    await requireAdminAuth();

    const { id } = params;

    const result = await pool.query(
      'DELETE FROM brand_locations WHERE id = $1 RETURNING id',
      [id]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Location not found' },
        { status: 404 }
      );
    }

    return NextResponse.json({
      message: 'Location deleted successfully',
      id: result.rows[0].id,
    });
  } catch (error: any) {
    console.error('DELETE /admin/locations/[id] error:', error);

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
