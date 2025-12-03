import { NextRequest, NextResponse } from 'next/server';
import { pool } from '@/lib/db';
import { auth } from '@clerk/nextjs/server';

const ADMIN_USER_IDS = process.env.ADMIN_USER_IDS?.split(',') || [];

function isAdmin(userId: string | null): boolean {
  return userId !== null && ADMIN_USER_IDS.includes(userId);
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { userId } = await auth();

    if (!isAdmin(userId)) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 403 }
      );
    }

    const resolvedParams = await params;
    const { id } = resolvedParams;

    const body = await request.json();

    const allowedFields = [
      'card_name',
      'card_type',
      'location_name',
      'location_address',
      'location_lat',
      'location_lng',
      'confidence_score',
      'verified',
      'design_variant',
    ];

    const updates: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    for (const [key, value] of Object.entries(body)) {
      if (allowedFields.includes(key)) {
        updates.push(`${key} = $${paramIndex}`);
        values.push(value);
        paramIndex++;
      }
    }

    if (updates.length === 0) {
      return NextResponse.json(
        { error: 'No valid fields to update' },
        { status: 400 }
      );
    }

    values.push(id);

    const query = `
      UPDATE card_templates
      SET ${updates.join(', ')}, updated_at = NOW()
      WHERE id = $${paramIndex}
      RETURNING *
    `;

    const result = await pool.query(query, values);

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Template not found' },
        { status: 404 }
      );
    }

    const template = result.rows[0];

    return NextResponse.json({
      template: {
        id: template.id,
        imageHash: template.image_hash,
        textSignature: template.text_signature,
        cardName: template.card_name,
        cardType: template.card_type,
        locationName: template.location_name,
        locationAddress: template.location_address,
        locationLat: template.location_lat ? parseFloat(template.location_lat) : null,
        locationLng: template.location_lng ? parseFloat(template.location_lng) : null,
        confidenceScore: parseFloat(template.confidence_score),
        usageCount: template.usage_count,
        verified: template.verified,
        designVariant: template.design_variant,
        createdBy: template.created_by,
        createdAt: template.created_at,
        updatedAt: template.updated_at,
      },
    });
  } catch (error) {
    console.error('Admin card template update API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { userId } = await auth();

    if (!isAdmin(userId)) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 403 }
      );
    }

    const resolvedParams = await params;
    const { id } = resolvedParams;

    const result = await pool.query(
      'DELETE FROM card_templates WHERE id = $1 RETURNING id',
      [id]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Template not found' },
        { status: 404 }
      );
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Admin card template delete API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
