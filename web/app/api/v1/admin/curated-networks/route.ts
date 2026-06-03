import { NextResponse } from 'next/server';
import { requireAdminAuth } from '@/lib/adminAuth';
import { getCuratedNetworks } from '@/lib/places/csvImporter';

export const dynamic = 'force-dynamic';

/**
 * GET /api/v1/admin/curated-networks
 * List curated networks for approval dropdowns.
 */
export async function GET() {
  try {
    await requireAdminAuth();

    const networks = getCuratedNetworks().map((n) => ({
      id: n.id,
      name: n.name,
      locationCount: n.locations.length,
    }));

    return NextResponse.json({
      success: true,
      networks,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error';
    if (message.includes('Unauthorized') || message.includes('Forbidden')) {
      return NextResponse.json({ error: message }, { status: 403 });
    }
    return NextResponse.json({ error: 'Failed to list networks' }, { status: 500 });
  }
}
