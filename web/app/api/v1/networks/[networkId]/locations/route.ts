import { NextRequest, NextResponse } from 'next/server';
import { getNetworkById, getCuratedLocationsNearby } from '@/lib/places/csvImporter';
import { searchPlaces } from '@/lib/places/search';
import { NetworkLocationsResponse } from '@/lib/places/types';

export async function GET(
  request: NextRequest,
  { params }: { params: { networkId: string } }
) {
  try {
    const networkId = params.networkId;
    const { searchParams } = new URL(request.url);

    const limit = searchParams.get('limit');
    const bbox = searchParams.get('bbox'); // bounding box: minLon,minLat,maxLon,maxLat
    const near = searchParams.get('near'); // lat,lon

    const limitNum = limit ? parseInt(limit) : 50;

    if (limitNum < 1 || limitNum > 1000) {
      return NextResponse.json(
        { error: 'Limit must be between 1 and 1000' },
        { status: 400 }
      );
    }

    // Try to get curated network first
    const network = getNetworkById(networkId);

    if (network) {
      // Filter locations based on bbox or near parameters
      let locations = network.locations;

      if (bbox) {
        const [minLon, minLat, maxLon, maxLat] = bbox.split(',').map(parseFloat);
        if ([minLon, minLat, maxLon, maxLat].some(isNaN)) {
          return NextResponse.json(
            { error: 'Invalid bbox format. Use: minLon,minLat,maxLon,maxLat' },
            { status: 400 }
          );
        }

        locations = locations.filter(loc =>
          loc.lon >= minLon && loc.lon <= maxLon &&
          loc.lat >= minLat && loc.lat <= maxLat
        );
      }

      if (near) {
        const [lat, lon] = near.split(',').map(parseFloat);
        if (isNaN(lat) || isNaN(lon)) {
          return NextResponse.json(
            { error: 'Invalid near format. Use: lat,lon' },
            { status: 400 }
          );
        }

        locations = getCuratedLocationsNearby(lat, lon, limitNum);
        locations = locations.filter(loc => loc.network_id === networkId);
      }

      // Limit results
      locations = locations.slice(0, limitNum);

      const response: NetworkLocationsResponse = {
        network: {
          id: network.id,
          name: network.name
        },
        locations: locations.map(loc => ({
          id: `curated:${loc.network_id}:${loc.lat}:${loc.lon}`,
          name: loc.network_name,
          lat: loc.lat,
          lon: loc.lon,
          radiusMeters: loc.radius_meters,
          notes: loc.notes
        }))
      };

      return NextResponse.json(response);
    }

    // If no curated network, try to search for the network using APIs
    // This is a fallback for networks not in our curated database
    const searchResults = await searchPlaces(networkId, {
      limit: limitNum,
      source: 'nominatim' // Prefer Nominatim for network searches
    });

    // Filter results to only include high-confidence network matches
    const networkResults = searchResults.results.filter(result =>
      result.networkGuessScore && result.networkGuessScore > 0.5
    );

    const response: NetworkLocationsResponse = {
      network: {
        id: networkId,
        name: networkId.replace(/-/g, ' ').replace(/\b\w/g, l => l.toUpperCase()) // Humanize network ID
      },
      locations: networkResults.map(result => ({
        id: result.id,
        name: result.name,
        lat: result.lat,
        lon: result.lon,
        radiusMeters: 100, // Default radius for API results
        notes: result.address
      }))
    };

    return NextResponse.json(response);
  } catch (error) {
    console.error('Network locations error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
