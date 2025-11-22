/**
 * In-memory database for development
 * TODO: Replace with PostgreSQL + PostGIS for production
 */

const { v4: uuidv4 } = require('uuid');
const { getDistance } = require('geolib');

// In-memory storage
const db = {
  users: new Map(),
  cards: new Map(),
  networks: new Map(),
  locations: new Map(),
};

// Seed initial data
function seedDatabase() {
  // Add sample networks
  const networks = [
    {
      id: 'costco',
      name: 'Costco Wholesale',
      canonical_names: ['Costco', 'Costco Wholesale', 'Costco Warehouse'],
      category: 'grocery',
      is_large_area: false,
      default_radius_meters: 100,
      tags: ['membership', 'grocery', 'wholesale'],
    },
    {
      id: 'whole-foods',
      name: 'Whole Foods Market',
      canonical_names: ['Whole Foods', 'Whole Foods Market'],
      category: 'grocery',
      is_large_area: false,
      default_radius_meters: 80,
      tags: ['grocery', 'organic'],
    },
    {
      id: 'kohls',
      name: "Kohl's",
      canonical_names: ["Kohl's", 'Kohls'],
      category: 'retail',
      is_large_area: false,
      default_radius_meters: 100,
      tags: ['retail', 'amazon-returns'],
    },
  ];

  networks.forEach((network) => {
    db.networks.set(network.id, network);
  });

  // Add sample locations (will be populated by CSV import)
  // For now, just a few hardcoded ones
  const locations = [
    {
      id: 'loc_costco_sf_001',
      network_id: 'costco',
      name: 'Costco Wholesale - San Francisco',
      address: '450 10th St, San Francisco, CA 94103',
      lat: 37.7749,
      lon: -122.4194,
      radius_meters: 100,
      phone: '+1-415-555-0123',
    },
    {
      id: 'loc_whole_foods_sf_001',
      network_id: 'whole-foods',
      name: 'Whole Foods Market - SOMA',
      address: '399 4th St, San Francisco, CA 94107',
      lat: 37.7820,
      lon: -122.4009,
      radius_meters: 80,
    },
    {
      id: 'loc_kohls_sf_001',
      network_id: 'kohls',
      name: "Kohl's - Geary St",
      address: '2675 Geary Blvd, San Francisco, CA 94118',
      lat: 37.7816,
      lon: -122.4501,
      radius_meters: 100,
    },
  ];

  locations.forEach((location) => {
    db.locations.set(location.id, location);
  });

  console.log('Database seeded with sample data');
}

// Initialize on first import
seedDatabase();

// ==================== User Operations ====================

function createUser(data) {
  const user = {
    id: `user_${uuidv4()}`,
    email: data.email,
    full_name: data.full_name || null,
    identity_provider: data.identity_provider || 'email',
    apple_user_id: data.apple_user_id || null,
    created_at: new Date().toISOString(),
    preferences: {
      sync_enabled: false,
      notification_radius_meters: 100,
    },
  };
  db.users.set(user.id, user);
  return user;
}

function getUserByEmail(email) {
  for (const user of db.users.values()) {
    if (user.email === email) {
      return user;
    }
  }
  return null;
}

function getUserByAppleId(appleUserId) {
  for (const user of db.users.values()) {
    if (user.apple_user_id === appleUserId) {
      return user;
    }
  }
  return null;
}

function getUserById(userId) {
  return db.users.get(userId) || null;
}

// ==================== Card Operations ====================

function createCard(userId, data) {
  const card = {
    id: `card_${uuidv4()}`,
    user_id: userId,
    name: data.name,
    barcode_type: data.barcode_type,
    payload_encrypted: data.payload_encrypted,
    tags: data.tags || [],
    network_ids: data.network_ids || [],
    valid_from: data.valid_from || null,
    valid_to: data.valid_to || null,
    one_time: data.one_time || false,
    used_at: null,
    metadata: data.metadata || {},
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    archived_at: null,
  };
  db.cards.set(card.id, card);
  return card;
}

function getCardById(cardId, userId) {
  const card = db.cards.get(cardId);
  if (!card || card.user_id !== userId) {
    return null;
  }
  return card;
}

function getCardsByUser(userId, options = {}) {
  const cards = Array.from(db.cards.values()).filter((card) => {
    if (card.user_id !== userId) return false;
    if (!options.include_archived && card.archived_at) return false;
    if (options.network_id && !card.network_ids.includes(options.network_id))
      return false;
    return true;
  });
  return cards;
}

function updateCard(cardId, userId, updates) {
  const card = getCardById(cardId, userId);
  if (!card) return null;

  Object.assign(card, updates, {
    updated_at: new Date().toISOString(),
  });

  db.cards.set(cardId, card);
  return card;
}

function deleteCard(cardId, userId) {
  const card = getCardById(cardId, userId);
  if (!card) return false;

  card.archived_at = new Date().toISOString();
  db.cards.set(cardId, card);
  return true;
}

// ==================== Network Operations ====================

function getAllNetworks(options = {}) {
  let networks = Array.from(db.networks.values());

  if (options.search) {
    const searchLower = options.search.toLowerCase();
    networks = networks.filter(
      (network) =>
        network.name.toLowerCase().includes(searchLower) ||
        network.canonical_names.some((name) =>
          name.toLowerCase().includes(searchLower)
        )
    );
  }

  if (options.category) {
    networks = networks.filter((network) => network.category === options.category);
  }

  return networks;
}

function getNetworkById(networkId) {
  return db.networks.get(networkId) || null;
}

function createNetwork(data) {
  const network = {
    id: data.id,
    name: data.name,
    canonical_names: data.canonical_names || [data.name],
    category: data.category || 'other',
    is_large_area: data.is_large_area || false,
    default_radius_meters: data.default_radius_meters || 100,
    tags: data.tags || [],
  };
  db.networks.set(network.id, network);
  return network;
}

// ==================== Location Operations ====================

function getNearbyLocations(lat, lon, radiusKm, options = {}) {
  const radiusMeters = radiusKm * 1000;
  const locations = Array.from(db.locations.values());

  // Filter by distance
  const nearby = locations
    .map((location) => {
      const distance = getDistance(
        { latitude: lat, longitude: lon },
        { latitude: location.lat, longitude: location.lon }
      );
      return { ...location, distance_meters: distance };
    })
    .filter((location) => location.distance_meters <= radiusMeters);

  // Filter by network if specified
  let filtered = nearby;
  if (options.network_ids && options.network_ids.length > 0) {
    filtered = filtered.filter((location) =>
      options.network_ids.includes(location.network_id)
    );
  }

  // Sort by distance
  filtered.sort((a, b) => a.distance_meters - b.distance_meters);

  // Limit results
  const limit = options.limit || 20;
  return filtered.slice(0, limit);
}

function getLocationsByNetwork(networkId, options = {}) {
  const locations = Array.from(db.locations.values()).filter(
    (location) => location.network_id === networkId
  );

  const offset = options.offset || 0;
  const limit = options.limit || 100;

  return {
    locations: locations.slice(offset, offset + limit),
    total: locations.length,
  };
}

function createLocation(data) {
  const location = {
    id: data.id || `loc_${data.network_id}_${uuidv4()}`,
    network_id: data.network_id,
    name: data.name,
    address: data.address,
    lat: data.lat,
    lon: data.lon,
    radius_meters: data.radius_meters || 100,
    phone: data.phone || null,
    hours: data.hours || null,
  };
  db.locations.set(location.id, location);
  return location;
}

// ==================== Region Refresh ====================

function getTopRegions(lat, lon, radiusKm, userNetworks, maxRegions = 20) {
  const allNearby = getNearbyLocations(lat, lon, radiusKm, {});

  // Prioritize locations for user's networks
  const priority = allNearby.filter((location) =>
    userNetworks.includes(location.network_id)
  );
  const other = allNearby.filter(
    (location) => !userNetworks.includes(location.network_id)
  );

  // Take top K
  const selected = [...priority, ...other].slice(0, maxRegions);

  // Assign priorities and format
  return selected.map((location, index) => ({
    id: location.id,
    network_id: location.network_id,
    network_name: db.networks.get(location.network_id)?.name || '',
    name: location.name,
    address: location.address,
    lat: location.lat,
    lon: location.lon,
    radius_meters: location.radius_meters,
    priority: userNetworks.includes(location.network_id) ? 1 : 2,
    distance_meters: location.distance_meters,
  }));
}

module.exports = {
  db,
  // User operations
  createUser,
  getUserByEmail,
  getUserByAppleId,
  getUserById,
  // Card operations
  createCard,
  getCardById,
  getCardsByUser,
  updateCard,
  deleteCard,
  // Network operations
  getAllNetworks,
  getNetworkById,
  createNetwork,
  // Location operations
  getNearbyLocations,
  getLocationsByNetwork,
  createLocation,
  // Region refresh
  getTopRegions,
};
