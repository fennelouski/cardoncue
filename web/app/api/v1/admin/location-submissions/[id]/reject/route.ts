import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';
import { requireAdminAuth } from '@/lib/adminAuth';

export const dynamic = 'force-dynamic';

const VALID_STATUSES = ['rejected', 'duplicate'];

/**
 * POST /api/v1/admin/location-submissions/[id]/reject
 */
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const admin = await requireAdminAuth();
    const { id } = params;

    if (!id) {
      return NextResponse.json({ error: 'Submission ID is required' }, { status: 400 });
    }

    const body = await request.json().catch(() => ({}));
    const {
      reason = '',
      status = 'rejected',
    } = body as { reason?: string; status?: string };

    if (!VALID_STATUSES.includes(status)) {
      return NextResponse.json(
        { error: `status must be one of: ${VALID_STATUSES.join(', ')}` },
        { status: 400 }
      );
    }

    const updated = await sql`
      UPDATE card_locations
      SET
        status = ${status},
        reviewed_at = NOW(),
        reviewed_by = ${admin.userId},
        rejection_reason = ${reason || null},
        updated_at = NOW()
      WHERE id = ${id}
      RETURNING *
    `;

    if (updated.rows.length === 0) {
      return NextResponse.json({ error: 'Submission not found' }, { status: 404 });
    }

    return NextResponse.json({
      success: true,
      submission: updated.rows[0],
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    if (message.includes('Unauthorized') || message.includes('Forbidden')) {
      return NextResponse.json({ error: message }, { status: 403 });
    }
    console.error('Reject submission error:', error);
    return NextResponse.json({ error: 'Failed to reject submission' }, { status: 500 });
  }
}
