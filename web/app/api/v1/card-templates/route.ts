import { NextRequest, NextResponse } from 'next/server';
import { pool } from '@/lib/db';
import { auth } from '@clerk/nextjs/server';

interface CreateTemplateRequest {
  imageHash: string;
  textSignature?: string;
  cardName: string;
  cardType?: string;
  locationName?: string;
  locationAddress?: string;
  locationLat?: number;
  locationLng?: number;
  confidenceScore?: number;
  designVariant?: string;
}

export async function POST(request: NextRequest) {
  try {
    const { userId } = await auth();

    if (!userId) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    const body: CreateTemplateRequest = await request.json();

    const {
      imageHash,
      textSignature,
      cardName,
      cardType,
      locationName,
      locationAddress,
      locationLat,
      locationLng,
      confidenceScore = 0.5,
      designVariant,
    } = body;

    if (!imageHash || imageHash.trim().length === 0) {
      return NextResponse.json(
        { error: 'imageHash is required' },
        { status: 400 }
      );
    }

    if (!cardName || cardName.trim().length === 0) {
      return NextResponse.json(
        { error: 'cardName is required' },
        { status: 400 }
      );
    }

    // Check if template with same hash already exists
    const existingQuery = `
      SELECT id, usage_count, confidence_score
      FROM card_templates
      WHERE image_hash = $1
      ${textSignature ? 'AND text_signature = $2' : ''}
      LIMIT 1
    `;

    const existingParams = textSignature ? [imageHash, textSignature] : [imageHash];
    const existingResult = await pool.query(existingQuery, existingParams);

    if (existingResult.rows.length > 0) {
      // Template exists, increment usage count and update confidence
      const existing = existingResult.rows[0];
      const newUsageCount = existing.usage_count + 1;
      const newConfidence = Math.min(
        1.0,
        (existing.confidence_score * existing.usage_count + confidenceScore) / newUsageCount
      );

      const updateQuery = `
        UPDATE card_templates
        SET
          usage_count = $1,
          confidence_score = $2,
          updated_at = NOW()
        WHERE id = $3
        RETURNING *
      `;

      const updateResult = await pool.query(updateQuery, [
        newUsageCount,
        newConfidence,
        existing.id,
      ]);

      return NextResponse.json({
        template: {
          id: updateResult.rows[0].id,
          imageHash: updateResult.rows[0].image_hash,
          usageCount: updateResult.rows[0].usage_count,
          confidenceScore: parseFloat(updateResult.rows[0].confidence_score),
        },
        created: false,
      });
    }

    // Create new template
    const insertQuery = `
      INSERT INTO card_templates (
        image_hash,
        text_signature,
        card_name,
        card_type,
        location_name,
        location_address,
        location_lat,
        location_lng,
        confidence_score,
        design_variant,
        created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING *
    `;

    const insertResult = await pool.query(insertQuery, [
      imageHash,
      textSignature || null,
      cardName,
      cardType || null,
      locationName || null,
      locationAddress || null,
      locationLat || null,
      locationLng || null,
      confidenceScore,
      designVariant || null,
      userId,
    ]);

    const template = insertResult.rows[0];

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
      },
      created: true,
    }, { status: 201 });
  } catch (error) {
    console.error('Card template creation API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
