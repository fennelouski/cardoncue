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
        b.*,
        json_agg(
          DISTINCT jsonb_build_object(
            'id', l.id,
            'name', l.name,
            'address', l.address,
            'city', l.city,
            'state', l.state,
            'verified', l.verified
          )
        ) FILTER (WHERE l.id IS NOT NULL) as locations,
        json_agg(
          DISTINCT jsonb_build_object(
            'id', ct.id,
            'cardName', ct.card_name,
            'verified', ct.verified,
            'usageCount', ct.usage_count
          )
        ) FILTER (WHERE ct.id IS NOT NULL) as templates
      FROM brands b
      LEFT JOIN locations l ON b.id = l.brand_id
      LEFT JOIN card_templates ct ON b.id = ct.brand_id
      WHERE b.id = $1
      GROUP BY b.id
      `,
      [id]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Brand not found' },
        { status: 404 }
      );
    }

    const brand = result.rows[0];

    return NextResponse.json({
      id: brand.id,
      name: brand.name,
      displayName: brand.display_name,
      description: brand.description,
      logoUrl: brand.logo_url,
      website: brand.website,
      primaryEmail: brand.primary_email,
      primaryPhone: brand.primary_phone,
      category: brand.category,
      verified: brand.verified,
      locations: brand.locations || [],
      templates: brand.templates || [],
      createdAt: brand.created_at,
      updatedAt: brand.updated_at,
    });
  } catch (error: any) {
    console.error('GET /admin/brands/[id] error:', error);

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
      name,
      displayName,
      description,
      logoUrl,
      website,
      primaryEmail,
      primaryPhone,
      category,
      verified,
    } = body;

    const updates: string[] = [];
    const values: any[] = [];
    let paramCount = 0;

    if (name !== undefined) {
      paramCount++;
      updates.push(`name = $${paramCount}`);
      values.push(name.trim().toLowerCase());
    }

    if (displayName !== undefined) {
      paramCount++;
      updates.push(`display_name = $${paramCount}`);
      values.push(displayName.trim());
    }

    if (description !== undefined) {
      paramCount++;
      updates.push(`description = $${paramCount}`);
      values.push(description || null);
    }

    if (logoUrl !== undefined) {
      paramCount++;
      updates.push(`logo_url = $${paramCount}`);
      values.push(logoUrl || null);
    }

    if (website !== undefined) {
      paramCount++;
      updates.push(`website = $${paramCount}`);
      values.push(website || null);
    }

    if (primaryEmail !== undefined) {
      paramCount++;
      updates.push(`primary_email = $${paramCount}`);
      values.push(primaryEmail || null);
    }

    if (primaryPhone !== undefined) {
      paramCount++;
      updates.push(`primary_phone = $${paramCount}`);
      values.push(primaryPhone || null);
    }

    if (category !== undefined) {
      paramCount++;
      updates.push(`category = $${paramCount}`);
      values.push(category || null);
    }

    if (verified !== undefined) {
      paramCount++;
      updates.push(`verified = $${paramCount}`);
      values.push(verified);
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
      UPDATE brands
      SET ${updates.join(', ')}
      WHERE id = $${paramCount + 1}
      RETURNING *
      `,
      values
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Brand not found' },
        { status: 404 }
      );
    }

    const brand = result.rows[0];

    return NextResponse.json({
      id: brand.id,
      name: brand.name,
      displayName: brand.display_name,
      description: brand.description,
      logoUrl: brand.logo_url,
      website: brand.website,
      primaryEmail: brand.primary_email,
      primaryPhone: brand.primary_phone,
      category: brand.category,
      verified: brand.verified,
      createdAt: brand.created_at,
      updatedAt: brand.updated_at,
    });
  } catch (error: any) {
    console.error('PATCH /admin/brands/[id] error:', error);

    if (error.message?.includes('Unauthorized') || error.message?.includes('Forbidden')) {
      return NextResponse.json(
        { error: error.message },
        { status: 403 }
      );
    }

    if (error.code === '23505') {
      return NextResponse.json(
        { error: 'Brand with this name already exists' },
        { status: 409 }
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
      'DELETE FROM brands WHERE id = $1 RETURNING id',
      [id]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Brand not found' },
        { status: 404 }
      );
    }

    return NextResponse.json({
      message: 'Brand deleted successfully',
      id: result.rows[0].id,
    });
  } catch (error: any) {
    console.error('DELETE /admin/brands/[id] error:', error);

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
