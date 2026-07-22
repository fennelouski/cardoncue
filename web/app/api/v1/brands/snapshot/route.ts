import { NextRequest, NextResponse } from 'next/server';
import { listBrandSnapshot } from '@/lib/services/brandService';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const limit = parseInt(searchParams.get('limit') || '200', 10);

    const brands = await listBrandSnapshot(Math.min(limit, 500));

    return NextResponse.json({
      ok: true,
      generatedAt: new Date().toISOString(),
      count: brands.length,
      brands,
    });
  } catch (error: any) {
    console.error('GET /v1/brands/snapshot error:', error);
    return NextResponse.json(
      { error: 'internal_error', message: error.message },
      { status: 500 }
    );
  }
}
