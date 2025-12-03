import { NextRequest, NextResponse } from 'next/server';
import { pool } from '@/lib/db';
import { requireAdminAuth } from '@/lib/adminAuth';

export async function GET(request: NextRequest) {
  try {
    await requireAdminAuth();

    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get('limit') || '50');
    const offset = parseInt(searchParams.get('offset') || '0');
    const search = searchParams.get('search') || '';
    const verified = searchParams.get('verified');

    let query = `
      SELECT
        t.*,
        b.display_name as brand_name,
        COUNT(DISTINCT tl.brand_location_id) as locations_count
      FROM card_templates t
      LEFT JOIN brands b ON t.brand_id = b.id
      LEFT JOIN template_brand_locations tl ON t.id = tl.template_id
      WHERE 1=1
    `;

    const params: any[] = [];
    let paramCount = 0;

    if (search) {
      paramCount++;
      query += ` AND t.card_name ILIKE $${paramCount}`;
      params.push(`%${search}%`);
    }

    if (verified !== null && verified !== undefined && verified !== '') {
      paramCount++;
      query += ` AND t.verified = $${paramCount}`;
      params.push(verified === 'true');
    }

    query += `
      GROUP BY t.id, b.id
      ORDER BY t.created_at DESC
      LIMIT $${paramCount + 1} OFFSET $${paramCount + 2}
    `;

    params.push(limit, offset);

    const result = await pool.query(query, params);

    const templates = result.rows.map(row => ({
      id: row.id,
      imageHash: row.image_hash,
      textSignature: row.text_signature,
      cardName: row.card_name,
      cardType: row.card_type,
      brandId: row.brand_id,
      brandName: row.brand_name,
      defaultBrandLocationId: row.default_brand_location_id,
      locationName: row.location_name,
      locationAddress: row.location_address,
      locationLat: row.location_lat ? parseFloat(row.location_lat) : null,
      locationLng: row.location_lng ? parseFloat(row.location_lng) : null,
      confidenceScore: row.confidence_score ? parseFloat(row.confidence_score) : null,
      usageCount: parseInt(row.usage_count) || 0,
      verified: row.verified,
      designVariant: row.design_variant,
      notes: row.notes,
      createdBy: row.created_by,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      locationsCount: parseInt(row.locations_count) || 0,
    }));

    // Get total count
    let countQuery = 'SELECT COUNT(*) FROM card_templates WHERE 1=1';
    const countParams: any[] = [];
    let countParamCount = 0;

    if (search) {
      countParamCount++;
      countQuery += ` AND card_name ILIKE $${countParamCount}`;
      countParams.push(`%${search}%`);
    }

    if (verified !== null && verified !== undefined && verified !== '') {
      countParamCount++;
      countQuery += ` AND verified = $${countParamCount}`;
      countParams.push(verified === 'true');
    }

    const countResult = await pool.query(countQuery, countParams);
    const total = parseInt(countResult.rows[0].count);

    return NextResponse.json({
      templates,
      pagination: {
        limit,
        offset,
        total,
      },
    });
  } catch (error: any) {
    console.error('GET /admin/card-templates error:', error);

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
