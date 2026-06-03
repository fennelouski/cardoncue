import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';
import { requireJwtAuth } from '@/lib/jwtAuth';

export const dynamic = 'force-dynamic';

/**
 * POST /api/v1/cards/sync
 * Upsert a card row in Postgres for location submissions (uses client-provided id).
 */
export async function POST(request: NextRequest) {
  try {
    const user = await requireJwtAuth(request);
    const body = await request.json();

    const {
      id,
      name,
      barcodeType = 'qr',
      payloadEncrypted,
      tags = [],
      networkIds = [],
      metadata = {},
    } = body;

    if (!id || !name || !payloadEncrypted) {
      return NextResponse.json(
        { error: 'id, name, and payloadEncrypted are required' },
        { status: 400 }
      );
    }

    const result = await sql`
      INSERT INTO cards (
        id,
        user_id,
        name,
        barcode_type,
        payload_encrypted,
        tags,
        network_ids,
        metadata
      )
      VALUES (
        ${id},
        ${user.id},
        ${name},
        ${barcodeType},
        ${payloadEncrypted},
        ${tags},
        ${networkIds},
        ${JSON.stringify(metadata)}::jsonb
      )
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        barcode_type = EXCLUDED.barcode_type,
        payload_encrypted = EXCLUDED.payload_encrypted,
        tags = EXCLUDED.tags,
        network_ids = EXCLUDED.network_ids,
        metadata = EXCLUDED.metadata,
        updated_at = NOW()
      WHERE cards.user_id = ${user.id}
      RETURNING id, user_id, name, network_ids, metadata, updated_at
    `;

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Card exists but belongs to another user' },
        { status: 403 }
      );
    }

    return NextResponse.json({
      success: true,
      card: result.rows[0],
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    if (message.includes('Unauthorized')) {
      return NextResponse.json({ error: message }, { status: 401 });
    }
    console.error('Card sync error:', error);
    return NextResponse.json({ error: 'Failed to sync card' }, { status: 500 });
  }
}
