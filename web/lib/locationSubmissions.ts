import { haversineDistanceMeters } from '@/lib/places/geo';

export const DEDUP_RADIUS_METERS = 50;

export type SubmissionStatus = 'pending' | 'approved' | 'rejected' | 'duplicate';
export type SubmissionSource = 'add_place' | 'manual_entry' | 'card_location';

export function buildCuratedKey(networkId: string, lat: number, lon: number): string {
  return `curated:${networkId}:${lat}:${lon}`;
}

export function coordinateKey(lat: number, lon: number): string {
  return `${lat},${lon}`;
}

/**
 * First network id from Postgres text[] or JSON array representation.
 */
export function firstNetworkId(networkIds: unknown, metadata?: Record<string, unknown> | null): string | null {
  if (metadata && typeof metadata === 'object') {
    const fromMeta = metadata.networkId;
    if (typeof fromMeta === 'string' && fromMeta.length > 0) {
      return fromMeta;
    }
  }

  if (Array.isArray(networkIds) && networkIds.length > 0) {
    const first = networkIds[0];
    if (typeof first === 'string' && first.length > 0) {
      return first;
    }
  }

  if (typeof networkIds === 'string') {
    try {
      const parsed = JSON.parse(networkIds);
      if (Array.isArray(parsed) && parsed.length > 0 && typeof parsed[0] === 'string') {
        return parsed[0];
      }
    } catch {
      // ignore
    }
  }

  return null;
}

export interface NearbySubmissionRow {
  id: string;
  latitude: string | number | null;
  longitude: string | number | null;
  suggested_network_id: string | null;
  report_count: number;
  status: string;
}

/**
 * Find an existing submission within dedup radius for the same network.
 */
export function findDuplicateSubmission(
  rows: NearbySubmissionRow[],
  lat: number,
  lon: number,
  networkId: string | null
): NearbySubmissionRow | null {
  for (const row of rows) {
    if (row.status === 'rejected') continue;

    const rowLat = row.latitude != null ? Number(row.latitude) : NaN;
    const rowLon = row.longitude != null ? Number(row.longitude) : NaN;
    if (Number.isNaN(rowLat) || Number.isNaN(rowLon)) continue;

    const sameNetwork =
      !networkId ||
      !row.suggested_network_id ||
      row.suggested_network_id === networkId;

    if (!sameNetwork) continue;

    const distance = haversineDistanceMeters(lat, lon, rowLat, rowLon);
    if (distance <= DEDUP_RADIUS_METERS) {
      return row;
    }
  }

  return null;
}
