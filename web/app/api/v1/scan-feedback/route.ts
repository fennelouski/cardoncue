import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';
import { extractBearerToken, verifyAccessToken } from '@/lib/jwtAuth';
import { parseScanFeedback } from '@/lib/scanFeedback';

// ponytail: query the table directly until volume warrants an admin dashboard
// ponytail: no rate limit yet — reuse lib/places/rateLimiter if this gets abused
export const dynamic = 'force-dynamic';

/**
 * POST /api/v1/scan-feedback
 * Record whether an in-app barcode scanned at the register. Auth is optional:
 * a valid bearer token attributes the row to a user, otherwise it is anonymous
 * (grouped by device_id). Upserts on submission_id so a thumb tap and a later
 * "tell us more" note collapse into one row.
 */
export async function POST(request: NextRequest) {
  try {
    const parsed = parseScanFeedback(await request.json().catch(() => null));
    if (!parsed.ok) {
      return NextResponse.json({ error: parsed.error }, { status: 400 });
    }
    const fb = parsed.value;

    const token = extractBearerToken(request);
    const userId = token ? verifyAccessToken(token)?.id ?? null : null;

    await sql`
      INSERT INTO scan_feedback (
        submission_id, device_id, user_id, card_id, barcode_type, worked, note
      )
      VALUES (
        ${fb.submissionId}, ${fb.deviceId}, ${userId}, ${fb.cardId},
        ${fb.barcodeType}, ${fb.worked}, ${fb.note}
      )
      ON CONFLICT (submission_id) DO UPDATE SET
        note = COALESCE(EXCLUDED.note, scan_feedback.note),
        worked = EXCLUDED.worked,
        updated_at = NOW()
    `;

    return NextResponse.json({ success: true }, { status: 201 });
  } catch (error) {
    console.error('Error recording scan feedback:', error);
    return NextResponse.json(
      { error: 'Failed to record scan feedback' },
      { status: 500 }
    );
  }
}
