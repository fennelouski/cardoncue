import { NextRequest, NextResponse } from 'next/server';
import { pool } from '@/lib/db';

interface MatchRequest {
  imageHash: string;
  textSignature?: string;
  limit?: number;
}

export async function POST(request: NextRequest) {
  try {
    const body: MatchRequest = await request.json();

    const { imageHash, textSignature, limit = 5 } = body;

    if (!imageHash || imageHash.trim().length === 0) {
      return NextResponse.json(
        { error: 'imageHash is required' },
        { status: 400 }
      );
    }

    // Query for matching templates
    // Prioritize: verified templates, then by usage count
    const query = `
      SELECT
        id,
        image_hash,
        text_signature,
        card_name,
        card_type,
        location_name,
        location_address,
        location_lat,
        location_lng,
        confidence_score,
        usage_count,
        verified,
        design_variant
      FROM card_templates
      WHERE
        image_hash = $1
        ${textSignature ? 'OR text_signature = $2' : ''}
      ORDER BY
        verified DESC,
        usage_count DESC,
        confidence_score DESC
      LIMIT $${textSignature ? '3' : '2'}
    `;

    const params = textSignature
      ? [imageHash, textSignature, limit]
      : [imageHash, limit];

    const result = await pool.query(query, params);

    const templates = result.rows.map(row => ({
      id: row.id,
      imageHash: row.image_hash,
      textSignature: row.text_signature,
      cardName: row.card_name,
      cardType: row.card_type,
      locationName: row.location_name,
      locationAddress: row.location_address,
      locationLat: row.location_lat ? parseFloat(row.location_lat) : null,
      locationLng: row.location_lng ? parseFloat(row.location_lng) : null,
      confidenceScore: row.confidence_score ? parseFloat(row.confidence_score) : 0.5,
      usageCount: row.usage_count,
      verified: row.verified,
      designVariant: row.design_variant,
    }));

    return NextResponse.json({
      matches: templates,
      count: templates.length,
    });
  } catch (error) {
    console.error('Card template match API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
