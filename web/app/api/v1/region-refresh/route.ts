import { NextRequest, NextResponse } from 'next/server';
import { searchPlaces } from '@/lib/places/search';
import { getCuratedLocationsNearby } from '@/lib/places/csvImporter';
import { RegionRefreshRequest, RegionRefreshResponse } from '@/lib/places/types';

function haversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const toRad = (d: number) => d * Math.PI / 180;
  const R = 6371000; // Earth radius in meters

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon/2) * Math.sin(dLon/2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

export async function POST(request: NextRequest) {
  try {
    const body: RegionRefreshRequest = await request.json();
    const { lat, lon, limit = 20 } = body;

    // Validate input
    if (typeof lat !== 'number' || typeof lon !== 'number' ||
        lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return NextResponse.json(
        { error: 'Invalid latitude or longitude' },
        { status: 400 }
      );
    }

    if (limit < 1 || limit > 100) {
      return NextResponse.json(
        { error: 'Limit must be between 1 and 100' },
        { status: 400 }
      );
    }

    // Get curated locations nearby
    const curatedLocations = getCuratedLocationsNearby(lat, lon, limit * 2); // Get more to allow for deduplication

    // Also search for places using external APIs (without query to get general POIs)
    const apiResults = await searchPlaces('', {
      lat,
      lon,
      limit: limit * 2,
      source: 'nominatim' // Prefer Nominatim for general POI search
    });

    // Combine and deduplicate
    const allLocations = [
      ...curatedLocations.map(loc => ({
        id: `curated:${loc.network_id}:${loc.lat}:${loc.lon}`,
        networkId: loc.network_id,
        name: loc.network_name,
        lat: loc.lat,
        lon: loc.lon,
        radiusMeters: loc.radius_meters,
        source: 'curated' as const,
        notes: loc.notes
      })),
      ...apiResults.map(place => ({
        id: place.id,
        networkId: undefined, // API results may not have network info
        name: place.name,
        lat: place.lat,
        lon: place.lon,
        radiusMeters: estimateRadius(place),
        source: place.dataSource,
        notes: place.address
      }))
    ];

    // Deduplicate by location (within ~50m)
    const deduplicated = deduplicateByLocation(allLocations);

    // Sort by distance and limit
    const sorted = deduplicated
      .map(loc => ({
        ...loc,
        distance: haversineDistance(lat, lon, loc.lat, loc.lon)
      }))
      .sort((a, b) => a.distance - b.distance)
      .slice(0, limit);

    const response: RegionRefreshResponse = {
      ok: true,
      locations: sorted
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Region refresh error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

function deduplicateByLocation(locations: any[]): any[] {
  const result: any[] = [];
  const seen = new Set<string>();

  for (const location of locations) {
    // Round coordinates to ~50m precision for deduplication
    const latRounded = Math.round(location.lat * 1000) / 1000;
    const lonRounded = Math.round(location.lon * 1000) / 1000;
    const key = `${latRounded},${lonRounded}`;

    if (!seen.has(key)) {
      seen.add(key);
      result.push(location);
    } else {
      // If duplicate location, prefer curated data
      const existingIndex = result.findIndex(r => {
        const rLatRounded = Math.round(r.lat * 1000) / 1000;
        const rLonRounded = Math.round(r.lon * 1000) / 1000;
        return `${rLatRounded},${rLonRounded}` === key;
      });

      if (existingIndex >= 0 && result[existingIndex].source !== 'curated' && location.source === 'curated') {
        result[existingIndex] = location; // Replace with curated
      }
    }
  }

  return result;
}

function estimateRadius(place: any): number {
  // Estimate radius based on place type
  const categories = place.categories || [];

  if (categories.some((cat: string) => cat.toLowerCase().includes('supermarket') || cat.toLowerCase().includes('grocery'))) {
    return 80;
  }

  if (categories.some((cat: string) => cat.toLowerCase().includes('library'))) {
    return 50;
  }

  if (categories.some((cat: string) => cat.toLowerCase().includes('theme') || cat.toLowerCase().includes('park'))) {
    return 2000; // Large area
  }

  if (categories.some((cat: string) => cat.toLowerCase().includes('mall') || cat.toLowerCase().includes('shopping'))) {
    return 150;
  }

  // Default radius
  return 100;
}
