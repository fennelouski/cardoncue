const fs = require('fs');
const path = require('path');
const Papa = require('papaparse');

// Load sample data from infra directory
const INFRA_DIR = path.join(__dirname, '..', '..', 'infra', 'importers');
const CURATED_DATA_FILE = path.join(__dirname, '..', 'data', 'curated-networks.json');

// Mapping of network IDs to their CSV files and names
const NETWORKS = {
  'costco': {
    name: 'Costco Wholesale',
    csvFile: 'costco-locations.csv'
  },
  'whole-foods': {
    name: 'Whole Foods Market',
    csvFile: 'whole-foods-locations.csv'
  },
  'kohls': {
    name: "Kohl's",
    csvFile: 'kohls-locations.csv'
  },
  'sfpl': {
    name: 'San Francisco Public Library',
    csvFile: 'sfpl-locations.csv'
  }
};

function loadCSV(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    const result = Papa.parse(content, {
      header: true,
      skipEmptyLines: true,
      transformHeader: (header) => header.toLowerCase().trim()
    });

    if (result.errors.length > 0) {
      console.error(`Errors parsing ${filePath}:`, result.errors);
      return [];
    }

    return result.data;
  } catch (error) {
    console.error(`Error reading ${filePath}:`, error);
    return [];
  }
}

function createCuratedNetworks() {
  const networks = [];

  for (const [networkId, networkInfo] of Object.entries(NETWORKS)) {
    const csvPath = path.join(INFRA_DIR, networkInfo.csvFile);

    if (!fs.existsSync(csvPath)) {
      console.warn(`CSV file not found: ${csvPath}`);
      continue;
    }

    const locations = loadCSV(csvPath);
    const curatedLocations = locations
      .filter(row => row.lat && row.lon)
      .map(row => ({
        network_id: networkId,
        network_name: networkInfo.name,
        lat: parseFloat(row.lat),
        lon: parseFloat(row.lon),
        radius_meters: parseFloat(row.radius || row.radius_meters || '100'),
        notes: row.name || row.address || ''
      }))
      .filter(loc => !isNaN(loc.lat) && !isNaN(loc.lon));

    if (curatedLocations.length > 0) {
      networks.push({
        id: networkId,
        name: networkInfo.name,
        locations: curatedLocations
      });

      console.log(`Loaded ${curatedLocations.length} locations for ${networkInfo.name}`);
    }
  }

  return networks;
}

function saveCuratedData(networks) {
  try {
    // Ensure data directory exists
    const dataDir = path.dirname(CURATED_DATA_FILE);
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }

    fs.writeFileSync(CURATED_DATA_FILE, JSON.stringify(networks, null, 2));
    console.log(`Saved ${networks.length} networks to ${CURATED_DATA_FILE}`);
  } catch (error) {
    console.error('Error saving curated data:', error);
  }
}

// Main execution
console.log('Seeding curated networks data...');

const networks = createCuratedNetworks();
saveCuratedData(networks);

console.log('Seeding complete!');
console.log(`Total networks: ${networks.length}`);
console.log(`Total locations: ${networks.reduce((sum, n) => sum + n.locations.length, 0)}`);
