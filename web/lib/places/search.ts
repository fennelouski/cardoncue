import { searchNominatim } from './nominatimConnector';
import { searchFoursquare } from './foursquareConnector';
import { getCuratedLocationsNearby } from './csvImporter';
import { Place, SearchOptions, SearchResponse } from './types';
import levenshtein from 'fast-levenshtein';

export async function searchPlaces(query: string, options: SearchOptions = {}): Promise<SearchResponse> {
  const { source = 'both' } = options;
  const results: Place[] = [];

  try {
    // Search curated locations first (exact matches)
    const curatedResults = await searchCurated(query, options);
    results.push(...curatedResults);

    // Search external APIs based on source preference
    if (source === 'nominatim' || source === 'both') {
      const nominatimResults = await searchNominatim(query, options);
      results.push(...nominatimResults);
    }

    if (source === 'foursquare' || source === 'both') {
      const foursquareResults = await searchFoursquare(query, options);
      results.push(...foursquareResults);
    }

    // Deduplicate and normalize results
    const deduplicated = deduplicatePlaces(results);

    // Sort by relevance (network score, then distance if coordinates provided)
    const sorted = sortPlaces(deduplicated, options.lat, options.lon, query);

    // Limit results
    const limited = sorted.slice(0, options.limit || 20);

    return {
      results: limited,
      total: limited.length,
      query
    };
  } catch (error) {
    console.error('Search places error:', error);
    return {
      results: [],
      total: 0,
      query
    };
  }
}

async function searchCurated(query: string, options: SearchOptions): Promise<Place[]> {
  // For curated search, we look for network matches and return their locations
  // This is a simplified implementation - in production you'd have better matching
  const curatedLocations = options.lat && options.lon
    ? getCuratedLocationsNearby(options.lat, options.lon, 50) // Get nearby curated locations
    : [];

  return curatedLocations
    .filter(loc => {
      // Simple text matching - could be improved with better search logic
      const nameMatch = loc.network_name.toLowerCase().includes(query.toLowerCase());
      const notesMatch = loc.notes?.toLowerCase().includes(query.toLowerCase());
      return nameMatch || notesMatch;
    })
    .map(loc => ({
      id: `curated:${loc.network_id}:${loc.lat}:${loc.lon}`,
      name: loc.network_name,
      address: loc.notes,
      lat: loc.lat,
      lon: loc.lon,
      categories: [loc.network_id],
      dataSource: 'curated' as const,
      networkGuessScore: 1.0 // Curated data is authoritative
    }));
}

function deduplicatePlaces(places: Place[]): Place[] {
  const result: Place[] = [];
  const seen = new Set<string>();

  for (const place of places) {
    // Create a key based on coordinates (rounded to ~10m precision)
    const latRounded = Math.round(place.lat * 1000) / 1000;
    const lonRounded = Math.round(place.lon * 1000) / 1000;
    const key = `${latRounded},${lonRounded}`;

    // Also consider name similarity
    const nameKey = normalizeName(place.name);

    const combinedKey = `${key}:${nameKey}`;

    if (!seen.has(combinedKey)) {
      seen.add(combinedKey);
      result.push(place);
    } else {
      // If we have a duplicate, keep the one with higher network score
      const existingIndex = result.findIndex(p => {
        const pLatRounded = Math.round(p.lat * 1000) / 1000;
        const pLonRounded = Math.round(p.lon * 1000) / 1000;
        const pNameKey = normalizeName(p.name);
        return `${pLatRounded},${pLonRounded}:${pNameKey}` === combinedKey;
      });

      if (existingIndex >= 0) {
        const existing = result[existingIndex];
        const existingScore = existing.networkGuessScore || 0;
        const currentScore = place.networkGuessScore || 0;

        if (currentScore > existingScore) {
          result[existingIndex] = place;
        }
      }
    }
  }

  return result;
}

function sortPlaces(places: Place[], userLat?: number, userLon?: number, query?: string): Place[] {
  return places.sort((a, b) => {
    // First, sort by network guess score (higher is better)
    const aScore = a.networkGuessScore || 0;
    const bScore = b.networkGuessScore || 0;

    if (aScore !== bScore) {
      return bScore - aScore;
    }

    // Then by distance if user location provided
    if (userLat && userLon) {
      const aDistance = haversineDistance(userLat, userLon, a.lat, a.lon);
      const bDistance = haversineDistance(userLat, userLon, b.lat, b.lon);

      if (Math.abs(aDistance - bDistance) > 100) { // Only consider significant distance differences
        return aDistance - bDistance;
      }
    }

    // Finally, prefer curated data over external APIs
    const sourceOrder = { curated: 0, nominatim: 1, foursquare: 2, google: 3 };
    const aOrder = sourceOrder[a.dataSource] || 999;
    const bOrder = sourceOrder[b.dataSource] || 999;

    return aOrder - bOrder;
  });
}

function normalizeName(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^\w\s]/g, '') // Remove punctuation
    .replace(/\s+/g, ' ') // Normalize whitespace
    .trim();
}

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
