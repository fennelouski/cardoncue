import Papa from 'papaparse';
import { CuratedLocation, Network } from './types';
import fs from 'fs';
import path from 'path';

// In-memory storage for curated networks (in production, use a database)
let curatedNetworks: Network[] = [];

const CURATED_DATA_FILE = path.join(process.cwd(), 'data', 'curated-networks.json');

// Load curated data on module initialization
loadCuratedData();

export function importCSV(csvContent: string, networkId: string, networkName: string): { success: boolean; imported: number; errors: string[] } {
  const errors: string[] = [];
  const importedLocations: CuratedLocation[] = [];

  try {
    const parseResult = Papa.parse(csvContent, {
      header: true,
      skipEmptyLines: true,
      transformHeader: (header: string) => header.toLowerCase().trim()
    });

    if (parseResult.errors.length > 0) {
      errors.push(...parseResult.errors.map(e => e.message));
      return { success: false, imported: 0, errors };
    }

    for (let i = 0; i < parseResult.data.length; i++) {
      const row = parseResult.data[i] as any;

      // Validate required fields
      const requiredFields = ['lat', 'lon'];
      const missingFields = requiredFields.filter(field => !row[field]);

      if (missingFields.length > 0) {
        errors.push(`Row ${i + 1}: Missing required fields: ${missingFields.join(', ')}`);
        continue;
      }

      // Validate coordinates
      const lat = parseFloat(row.lat);
      const lon = parseFloat(row.lon);
      const radiusMeters = parseFloat(row.radius || row.radius_meters || '100');

      if (isNaN(lat) || isNaN(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        errors.push(`Row ${i + 1}: Invalid coordinates (lat: ${row.lat}, lon: ${row.lon})`);
        continue;
      }

      if (isNaN(radiusMeters) || radiusMeters <= 0) {
        errors.push(`Row ${i + 1}: Invalid radius: ${row.radius || row.radius_meters}`);
        continue;
      }

      importedLocations.push({
        network_id: networkId,
        network_name: networkName,
        lat,
        lon,
        radius_meters: radiusMeters,
        notes: row.name || row.address || row.notes || ''
      });
    }

    if (importedLocations.length === 0) {
      return { success: false, imported: 0, errors: ['No valid locations found in CSV'] };
    }

    // Create or update network
    const existingNetworkIndex = curatedNetworks.findIndex(n => n.id === networkId);
    const newNetwork: Network = {
      id: networkId,
      name: networkName,
      locations: importedLocations
    };

    if (existingNetworkIndex >= 0) {
      // Merge with existing network
      const existingLocations = curatedNetworks[existingNetworkIndex].locations;
      const locationMap = new Map<string, CuratedLocation>();

      // Add existing locations
      for (const loc of existingLocations) {
        const key = `${loc.lat},${loc.lon}`;
        locationMap.set(key, loc);
      }

      // Add new locations (will overwrite if same coordinates)
      for (const loc of importedLocations) {
        const key = `${loc.lat},${loc.lon}`;
        locationMap.set(key, loc);
      }

      curatedNetworks[existingNetworkIndex].locations = Array.from(locationMap.values());
    } else {
      // Add new network
      curatedNetworks.push(newNetwork);
    }

    // Save to file
    saveCuratedData();

    return { success: true, imported: importedLocations.length, errors };
  } catch (error) {
    return { success: false, imported: 0, errors: [`Import failed: ${error.message}`] };
  }
}

export function getCuratedNetworks(): Network[] {
  return curatedNetworks;
}

export function getNetworkById(networkId: string): Network | null {
  return curatedNetworks.find(n => n.id === networkId) || null;
}

export function getCuratedLocationsNearby(lat: number, lon: number, limit: number = 20): CuratedLocation[] {
  const locations: Array<CuratedLocation & { distance: number }> = [];

  for (const network of curatedNetworks) {
    for (const location of network.locations) {
      const distance = haversineDistance(lat, lon, location.lat, location.lon);
      locations.push({ ...location, distance });
    }
  }

  // Sort by distance and return top results
  return locations
    .sort((a, b) => a.distance - b.distance)
    .slice(0, limit);
}

function loadCuratedData(): void {
  try {
    if (fs.existsSync(CURATED_DATA_FILE)) {
      const data = fs.readFileSync(CURATED_DATA_FILE, 'utf-8');
      curatedNetworks = JSON.parse(data);
    }
  } catch (error) {
    console.warn('Failed to load curated data:', error);
    curatedNetworks = [];
  }
}

function saveCuratedData(): void {
  try {
    // Ensure data directory exists
    const dataDir = path.dirname(CURATED_DATA_FILE);
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }

    fs.writeFileSync(CURATED_DATA_FILE, JSON.stringify(curatedNetworks, null, 2));
  } catch (error) {
    console.error('Failed to save curated data:', error);
  }
}

// Haversine distance calculation
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
