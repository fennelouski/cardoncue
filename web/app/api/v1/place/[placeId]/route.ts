import { NextRequest, NextResponse } from 'next/server';
import { placesCache } from '@/lib/places/cache';
import { searchNominatim } from '@/lib/places/nominatimConnector';
import { searchFoursquare } from '@/lib/places/foursquareConnector';

export async function GET(
  request: NextRequest,
  { params }: { params: { placeId: string } }
) {
  try {
    const placeId = params.placeId;

    if (!placeId) {
      return NextResponse.json(
        { error: 'Place ID is required' },
        { status: 400 }
      );
    }

    // Check cache first
    const cacheKey = `place:${placeId}`;
    const cached = await placesCache.get<any>(cacheKey);

    if (cached) {
      return NextResponse.json(cached);
    }

    // Try to fetch from appropriate source based on placeId prefix
    let placeData = null;

    if (placeId.startsWith('nominatim:')) {
      // Try to reconstruct the search that would find this place
      // This is a simplified approach - in production you'd store more metadata
      const placeIdParts = placeId.split(':');
      if (placeIdParts.length >= 2) {
        const osmId = placeIdParts[1];
        // For now, return a placeholder - you'd need to implement reverse lookup
        placeData = {
          id: placeId,
          name: 'Place details not available',
          source: 'nominatim',
          note: 'Detailed place information requires additional API calls'
        };
      }
    } else if (placeId.startsWith('foursquare:')) {
      // Similar approach for Foursquare
      placeData = {
        id: placeId,
        name: 'Place details not available',
        source: 'foursquare',
        note: 'Detailed place information requires additional API calls'
      };
    } else if (placeId.startsWith('curated:')) {
      // For curated places, we might not have detailed info beyond what's in the cache
      placeData = {
        id: placeId,
        name: 'Curated location',
        source: 'curated',
        note: 'This is a curated location with basic information'
      };
    }

    if (!placeData) {
      return NextResponse.json(
        { error: 'Place not found' },
        { status: 404 }
      );
    }

    // Cache the result
    await placesCache.set(cacheKey, placeData, 86400); // 24 hours

    return NextResponse.json(placeData);

  } catch (error) {
    console.error('Place details error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
