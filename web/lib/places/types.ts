export interface Place {
  id: string;
  name: string;
  address?: string;
  lat: number;
  lon: number;
  categories: string[];
  dataSource: 'nominatim' | 'foursquare' | 'google' | 'curated';
  networkGuessScore?: number; // 0-1, how likely this place belongs to a network
  raw?: any; // Original API response data
}

export interface CuratedLocation {
  network_id: string;
  network_name: string;
  lat: number;
  lon: number;
  radius_meters: number;
  notes?: string;
}

export interface Network {
  id: string;
  name: string;
  locations: CuratedLocation[];
}

export interface SearchOptions {
  lat?: number;
  lon?: number;
  limit?: number;
  source?: 'nominatim' | 'foursquare' | 'google' | 'both';
}

export interface RegionRefreshRequest {
  lat: number;
  lon: number;
  limit?: number;
}

export interface RegionRefreshResponse {
  ok: boolean;
  locations: Array<{
    id: string;
    networkId?: string;
    name: string;
    lat: number;
    lon: number;
    radiusMeters: number;
    source: string;
    distance?: number;
  }>;
}

export interface SearchResponse {
  results: Place[];
  total: number;
  query: string;
}

export interface NetworkLocationsResponse {
  network: {
    id: string;
    name: string;
  };
  locations: Array<{
    id: string;
    name: string;
    lat: number;
    lon: number;
    radiusMeters: number;
    notes?: string;
  }>;
}
