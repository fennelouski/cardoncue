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
    const category = searchParams.get('category') || '';
    const verified = searchParams.get('verified');

    let query = `
      SELECT
        b.*,
        COUNT(DISTINCT l.id) as locations_count,
        COUNT(DISTINCT ct.id) as templates_count
      FROM brands b
      LEFT JOIN locations l ON b.id = l.brand_id
      LEFT JOIN card_templates ct ON b.id = ct.brand_id
      WHERE 1=1
    `;

    const params: any[] = [];
    let paramCount = 0;

    if (search) {
      paramCount++;
      query += ` AND (b.name ILIKE $${paramCount} OR b.display_name ILIKE $${paramCount})`;
      params.push(`%${search}%`);
    }

    if (category) {
      paramCount++;
      query += ` AND b.category = $${paramCount}`;
      params.push(category);
    }

    if (verified !== null && verified !== undefined && verified !== '') {
      paramCount++;
      query += ` AND b.verified = $${paramCount}`;
      params.push(verified === 'true');
    }

    query += `
      GROUP BY b.id
      ORDER BY b.created_at DESC
      LIMIT $${paramCount + 1} OFFSET $${paramCount + 2}
    `;

    params.push(limit, offset);

    const result = await pool.query(query, params);

    const brands = result.rows.map(row => ({
      id: row.id,
      name: row.name,
      displayName: row.display_name,
      description: row.description,
      logoUrl: row.logo_url,
      website: row.website,
      primaryEmail: row.primary_email,
      primaryPhone: row.primary_phone,
      category: row.category,
      verified: row.verified,
      locationsCount: parseInt(row.locations_count) || 0,
      templatesCount: parseInt(row.templates_count) || 0,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));

    // Get total count
    const countResult = await pool.query(
      `SELECT COUNT(*) FROM brands WHERE 1=1 ${search ? 'AND (name ILIKE $1 OR display_name ILIKE $1)' : ''}`,
      search ? [`%${search}%`] : []
    );
    const total = parseInt(countResult.rows[0].count);

    return NextResponse.json({
      brands,
      pagination: {
        limit,
        offset,
        total,
      },
    });
  } catch (error: any) {
    console.error('GET /admin/brands error:', error);

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
      name,
      displayName,
      description,
      logoUrl,
      website,
      primaryEmail,
      primaryPhone,
      category,
      verified = false,
    } = body;

    if (!name || !displayName) {
      return NextResponse.json(
        { error: 'Name and display name are required' },
        { status: 400 }
      );
    }

    const result = await pool.query(
      `
      INSERT INTO brands (
        name, display_name, description, logo_url, website,
        primary_email, primary_phone, category, verified
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *
      `,
      [
        name.trim().toLowerCase(),
        displayName.trim(),
        description || null,
        logoUrl || null,
        website || null,
        primaryEmail || null,
        primaryPhone || null,
        category || null,
        verified,
      ]
    );

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
    }, { status: 201 });
  } catch (error: any) {
    console.error('POST /admin/brands error:', error);

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
