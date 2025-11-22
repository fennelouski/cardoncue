import { NextRequest, NextResponse } from 'next/server';
import { searchPlaces } from '@/lib/places/search';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);

    const query = searchParams.get('query');
    const lat = searchParams.get('lat');
    const lon = searchParams.get('lon');
    const limit = searchParams.get('limit');
    const source = searchParams.get('source');

    if (!query || query.trim().length < 2) {
      return NextResponse.json(
        { error: 'Query parameter is required and must be at least 2 characters' },
        { status: 400 }
      );
    }

    const options: any = {
      limit: limit ? parseInt(limit) : 20,
      source: source || 'both'
    };

    if (lat && lon) {
      const latNum = parseFloat(lat);
      const lonNum = parseFloat(lon);

      if (isNaN(latNum) || isNaN(lonNum) || latNum < -90 || latNum > 90 || lonNum < -180 || lonNum > 180) {
        return NextResponse.json(
          { error: 'Invalid latitude or longitude' },
          { status: 400 }
        );
      }

      options.lat = latNum;
      options.lon = lonNum;
    }

    const results = await searchPlaces(query.trim(), options);

    return NextResponse.json(results);
  } catch (error) {
    console.error('Search API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
