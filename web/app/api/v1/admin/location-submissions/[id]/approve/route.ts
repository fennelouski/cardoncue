import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';
import { requireAdminAuth } from '@/lib/adminAuth';
import { addLocationToNetwork, getNetworkById } from '@/lib/places/csvImporter';
import { buildCuratedKey } from '@/lib/locationSubmissions';

export const dynamic = 'force-dynamic';

/**
 * POST /api/v1/admin/location-submissions/[id]/approve
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

    const body = await request.json();
    const {
      networkId,
      networkName,
      radiusMeters = 100,
      displayName,
    } = body;

    if (!networkId) {
      return NextResponse.json({ error: 'networkId is required' }, { status: 400 });
    }

    const submissionResult = await sql`
      SELECT *
      FROM card_locations
      WHERE id = ${id}
    `;

    if (submissionResult.rows.length === 0) {
      return NextResponse.json({ error: 'Submission not found' }, { status: 404 });
    }

    const submission = submissionResult.rows[0];

    if (submission.status === 'approved') {
      return NextResponse.json({
        success: true,
        alreadyApproved: true,
        approvedCuratedKey: submission.approved_curated_key,
      });
    }

    const lat = submission.latitude != null ? Number(submission.latitude) : null;
    const lon = submission.longitude != null ? Number(submission.longitude) : null;

    if (lat == null || lon == null || Number.isNaN(lat) || Number.isNaN(lon)) {
      return NextResponse.json(
        { error: 'Submission is missing valid coordinates' },
        { status: 400 }
      );
    }

    const network = getNetworkById(networkId);
    const resolvedNetworkName =
      networkName || network?.name || networkId;

    const notesParts = [
      displayName || submission.location_name,
      submission.address,
      submission.city,
      submission.state,
    ].filter(Boolean);

    const mergeResult = addLocationToNetwork(networkId, {
      lat,
      lon,
      radiusMeters: Number(radiusMeters) || 100,
      notes: notesParts.join(', '),
      networkName: resolvedNetworkName,
    });

    if (!mergeResult.success) {
      return NextResponse.json(
        { error: mergeResult.error || 'Failed to add to curated network' },
        { status: 500 }
      );
    }

    const curatedKey = mergeResult.curatedKey || buildCuratedKey(networkId, lat, lon);

    const updated = await sql`
      UPDATE card_locations
      SET
        status = 'approved',
        reviewed_at = NOW(),
        reviewed_by = ${admin.userId},
        approved_curated_key = ${curatedKey},
        suggested_network_id = ${networkId},
        updated_at = NOW()
      WHERE id = ${id}
      RETURNING *
    `;

    return NextResponse.json({
      success: true,
      submission: updated.rows[0],
      curated: {
        key: curatedKey,
        created: mergeResult.created,
        networkId,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    if (message.includes('Unauthorized') || message.includes('Forbidden')) {
      return NextResponse.json({ error: message }, { status: 403 });
    }
    console.error('Approve submission error:', error);
    return NextResponse.json({ error: 'Failed to approve submission' }, { status: 500 });
  }
}
