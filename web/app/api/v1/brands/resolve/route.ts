import { NextRequest, NextResponse } from 'next/server';
import { resolveBrand } from '@/lib/services/brandService';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const name = searchParams.get('name');
    const website = searchParams.get('website');
    const locationName = searchParams.get('locationName');

    if (!name && !locationName) {
      return NextResponse.json(
        { error: 'name or locationName query parameter is required' },
        { status: 400 }
      );
    }

    const result = await resolveBrand({
      name: name ?? locationName ?? '',
      website,
      locationName,
    });

    return NextResponse.json({
      ok: true,
      brand: {
        name: result.name,
        displayName: result.displayName,
        category: result.category,
        domain: result.domain,
        logoUrl: result.logoUrl,
        source: result.source,
        tier: result.tier,
        verified: result.verified,
      },
    });
  } catch (error: any) {
    console.error('GET /v1/brands/resolve error:', error);
    return NextResponse.json(
      { error: 'internal_error', message: error.message },
      { status: 500 }
    );
  }
}
