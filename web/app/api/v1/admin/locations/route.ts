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
    const brandId = searchParams.get('brandId') || '';
    const verified = searchParams.get('verified');
    const city = searchParams.get('city') || '';
    const state = searchParams.get('state') || '';

    let query = `
      SELECT
        l.*,
        b.name as brand_name,
        b.display_name as brand_display_name,
        COUNT(DISTINCT tl.template_id) as templates_count
      FROM brand_locations l
      LEFT JOIN brands b ON l.brand_id = b.id
      LEFT JOIN template_brand_locations tl ON l.id = tl.brand_location_id
      WHERE 1=1
    `;

    const params: any[] = [];
    let paramCount = 0;

    if (search) {
      paramCount++;
      query += ` AND (l.name ILIKE $${paramCount} OR l.address ILIKE $${paramCount})`;
      params.push(`%${search}%`);
    }

    if (brandId) {
      paramCount++;
      query += ` AND l.brand_id = $${paramCount}`;
      params.push(brandId);
    }

    if (city) {
      paramCount++;
      query += ` AND l.city ILIKE $${paramCount}`;
      params.push(`%${city}%`);
    }

    if (state) {
      paramCount++;
      query += ` AND l.state ILIKE $${paramCount}`;
      params.push(`%${state}%`);
    }

    if (verified !== null && verified !== undefined && verified !== '') {
      paramCount++;
      query += ` AND l.verified = $${paramCount}`;
      params.push(verified === 'true');
    }

    query += `
      GROUP BY l.id, b.id
      ORDER BY l.created_at DESC
      LIMIT $${paramCount + 1} OFFSET $${paramCount + 2}
    `;

    params.push(limit, offset);

    const result = await pool.query(query, params);

    const locations = result.rows.map(row => ({
      id: row.id,
      brandId: row.brand_id,
      brandName: row.brand_name,
      brandDisplayName: row.brand_display_name,
      name: row.name,
      address: row.address,
      city: row.city,
      state: row.state,
      zipCode: row.zip_code,
      country: row.country,
      latitude: row.latitude ? parseFloat(row.latitude) : null,
      longitude: row.longitude ? parseFloat(row.longitude) : null,
      phone: row.phone,
      email: row.email,
      website: row.website,
      regularHours: row.regular_hours,
      specialHours: row.special_hours,
      timezone: row.timezone,
      placeId: row.place_id,
      verified: row.verified,
      notes: row.notes,
      templatesCount: parseInt(row.templates_count) || 0,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));

    // Get total count
    let countQuery = 'SELECT COUNT(*) FROM brand_locations WHERE 1=1';
    const countParams: any[] = [];
    let countParamCount = 0;

    if (search) {
      countParamCount++;
      countQuery += ` AND (name ILIKE $${countParamCount} OR address ILIKE $${countParamCount})`;
      countParams.push(`%${search}%`);
    }

    if (brandId) {
      countParamCount++;
      countQuery += ` AND brand_id = $${countParamCount}`;
      countParams.push(brandId);
    }

    const countResult = await pool.query(countQuery, countParams);
    const total = parseInt(countResult.rows[0].count);

    return NextResponse.json({
      locations,
      pagination: {
        limit,
        offset,
        total,
      },
    });
  } catch (error: any) {
    console.error('GET /admin/locations error:', error);

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

export async function POST(request: NextRequest) {
  try {
    await requireAdminAuth();

    const body = await request.json();
    const {
      brandId,
      name,
      address,
      city,
      state,
      zipCode,
      country = 'US',
      latitude,
      longitude,
      phone,
      email,
      website,
      regularHours,
      specialHours,
      timezone = 'America/New_York',
      placeId,
      verified = false,
      notes,
    } = body;

    if (!name || !address || latitude === undefined || longitude === undefined) {
      return NextResponse.json(
        { error: 'Name, address, latitude, and longitude are required' },
        { status: 400 }
      );
    }

    // Validate coordinates
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return NextResponse.json(
        { error: 'Invalid coordinates' },
        { status: 400 }
      );
    }

    const result = await pool.query(
      `
      INSERT INTO brand_locations (
        brand_id, name, address, city, state, zip_code, country,
        latitude, longitude, phone, email, website,
        regular_hours, special_hours, timezone, place_id, verified, notes
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
      RETURNING *
      `,
      [
        brandId || null,
        name.trim(),
        address.trim(),
        city?.trim() || null,
        state?.trim() || null,
        zipCode?.trim() || null,
        country,
        latitude,
        longitude,
        phone || null,
        email || null,
        website || null,
        regularHours ? JSON.stringify(regularHours) : null,
        specialHours ? JSON.stringify(specialHours) : null,
        timezone,
        placeId || null,
        verified,
        notes || null,
      ]
    );

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
    }, { status: 201 });
  } catch (error: any) {
    console.error('POST /admin/locations error:', error);

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
