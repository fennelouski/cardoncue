import axios from 'axios';
import { placesCache } from './cache';
import { foursquareLimiter } from './rateLimiter';
import { Place, SearchOptions } from './types';

const API_KEY = process.env.FOURSQUARE_API_KEY;
const CACHE_TTL = parseInt(process.env.PLACES_CACHE_TTL_SECONDS || '86400');

export async function searchFoursquare(query: string, options: SearchOptions = {}): Promise<Place[]> {
  if (!API_KEY) {
    return []; // Skip if no API key
  }

  const { lat, lon, limit = 10 } = options;
  const cacheKey = `foursquare:search:${query}:${lat || ''}:${lon || ''}:${limit}`;

  // Check cache first
  const cached = await placesCache.get<Place[]>(cacheKey);
  if (cached) {
    return cached;
  }

  // Check rate limit
  if (!foursquareLimiter.isAllowed(API_KEY)) {
    console.warn('Foursquare rate limit exceeded, returning empty results');
    return [];
  }

  try {
    const params: any = {
      query,
      limit,
      fields: 'fsq_id,name,location,categories,chains'
    };

    if (lat && lon) {
      params.ll = `${lat},${lon}`;
      params.radius = 10000; // 10km radius
    }

    const response = await axios.get('https://api.foursquare.com/v3/places/search', {
      params,
      headers: {
        'Authorization': API_KEY,
        'Accept': 'application/json'
      },
      timeout: 10000
    });

    const results: Place[] = response.data.results.map((item: any) => ({
      id: `foursquare:${item.fsq_id}`,
      name: item.name,
      address: item.location?.formatted_address || item.location?.address,
      lat: item.location?.lat,
      lon: item.location?.lng,
      categories: item.categories?.map((cat: any) => cat.name) || [],
      dataSource: 'foursquare' as const,
      networkGuessScore: calculateNetworkGuessScore(item, query),
      raw: item
    })).filter((place: Place) => place.lat && place.lon); // Filter out results without coordinates

    // Cache results
    await placesCache.set(cacheKey, results, CACHE_TTL);

    return results;
  } catch (error) {
    console.error('Foursquare search error:', error);
    return [];
  }
}

function calculateNetworkGuessScore(item: any, query: string): number {
  const name = item.name?.toLowerCase() || '';
  const queryLower = query.toLowerCase();

  let score = 0;

  // Name contains query
  if (name.includes(queryLower)) {
    score += 0.6;
  }

  // Chain information (indicates it's part of a larger network)
  if (item.chains && item.chains.length > 0) {
    score += 0.4;
  }

  // Category hints
  const relevantCategories = ['Food', 'Shopping', 'Arts and Entertainment', 'Education'];
  const hasRelevantCategory = item.categories?.some((cat: any) =>
    relevantCategories.some(rc => cat.name?.includes(rc))
  );
  if (hasRelevantCategory) {
    score += 0.2;
  }

  return Math.min(score, 1.0);
}
