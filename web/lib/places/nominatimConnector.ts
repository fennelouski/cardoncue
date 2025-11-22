import axios from 'axios';
import { placesCache } from './cache';
import { nominatimLimiter } from './rateLimiter';
import { Place, SearchOptions } from './types';

const BASE_URL = process.env.NOMINATIM_BASE_URL || 'https://nominatim.openstreetmap.org';
const USER_AGENT = process.env.NOMINATIM_USER_AGENT || 'CardOnCue/1.0 (hello@cardoncue.com)';
const CACHE_TTL = parseInt(process.env.PLACES_CACHE_TTL_SECONDS || '86400');

export async function searchNominatim(query: string, options: SearchOptions = {}): Promise<Place[]> {
  const { lat, lon, limit = 10 } = options;
  const cacheKey = `nominatim:search:${query}:${lat || ''}:${lon || ''}:${limit}`;

  // Check cache first
  const cached = await placesCache.get<Place[]>(cacheKey);
  if (cached) {
    return cached;
  }

  // Check rate limit
  if (!nominatimLimiter.isAllowed('global')) {
    console.warn('Nominatim rate limit exceeded, returning empty results');
    return [];
  }

  try {
    const params: any = {
      q: query,
      format: 'jsonv2',
      limit,
      addressdetails: 1,
      extratags: 1,
      namedetails: 1
    };

    if (lat && lon) {
      // Use bounded search around the location
      const radiusKm = 10; // Search within 10km radius
      params.bounded = 1;
      params.viewbox = [
        lon - (radiusKm / 111.32 / Math.cos(lat * Math.PI / 180)), // ~111km per degree latitude
        lat - (radiusKm / 111.32),
        lon + (radiusKm / 111.32 / Math.cos(lat * Math.PI / 180)),
        lat + (radiusKm / 111.32)
      ].join(',');
    }

    const response = await axios.get(`${BASE_URL}/search`, {
      params,
      headers: {
        'User-Agent': USER_AGENT
      },
      timeout: 10000 // 10 second timeout
    });

    const results: Place[] = response.data.map((item: any) => ({
      id: `nominatim:${item.place_id}`,
      name: item.display_name.split(',')[0] || item.display_name, // Take first part as name
      address: item.display_name,
      lat: parseFloat(item.lat),
      lon: parseFloat(item.lon),
      categories: [
        item.type,
        ...(item.class ? [item.class] : []),
        ...(item.extratags?.brand ? [item.extratags.brand] : []),
        ...(item.extratags?.operator ? [item.extratags.operator] : [])
      ].filter(Boolean),
      dataSource: 'nominatim' as const,
      networkGuessScore: calculateNetworkGuessScore(item, query),
      raw: item
    }));

    // Cache results
    await placesCache.set(cacheKey, results, CACHE_TTL);

    return results;
  } catch (error) {
    console.error('Nominatim search error:', error);
    return [];
  }
}

function calculateNetworkGuessScore(item: any, query: string): number {
  const name = item.display_name?.toLowerCase() || '';
  const brand = item.extratags?.brand?.toLowerCase() || '';
  const operator = item.extratags?.operator?.toLowerCase() || '';
  const queryLower = query.toLowerCase();

  let score = 0;

  // Exact brand/operator match with query
  if (brand === queryLower || operator === queryLower) {
    score += 0.8;
  }

  // Brand/operator contains query
  if (brand.includes(queryLower) || operator.includes(queryLower)) {
    score += 0.6;
  }

  // Name contains query
  if (name.includes(queryLower)) {
    score += 0.4;
  }

  // Category hints (supermarket, library, etc.)
  const relevantCategories = ['shop', 'amenity', 'leisure', 'tourism'];
  if (relevantCategories.includes(item.class)) {
    score += 0.2;
  }

  // Specific venue types
  if (item.type === 'supermarket' || item.type === 'library' || item.type === 'theme_park') {
    score += 0.3;
  }

  return Math.min(score, 1.0);
}
