/**
 * GET /v1/locations/nearby
 * Find nearby locations
 */

const { requireAuth } = require('../../utils/auth');
const { getNearbyLocations, getNetworkById } = require('../../utils/db');

async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'method_not_allowed', message: 'Only GET allowed' });
  }

  const { lat, lon, radius_km, types, network_ids, limit } = req.query;

  // Validate required fields
  if (!lat || !lon) {
    return res.status(400).json({
      error: 'invalid_request',
      message: 'Missing required parameters: lat, lon',
    });
  }

  const latitude = parseFloat(lat);
  const longitude = parseFloat(lon);

  // Validate ranges
  if (isNaN(latitude) || latitude < -90 || latitude > 90) {
    return res.status(400).json({
      error: 'invalid_request',
      message: 'lat must be a number between -90 and 90',
    });
  }

  if (isNaN(longitude) || longitude < -180 || longitude > 180) {
    return res.status(400).json({
      error: 'invalid_request',
      message: 'lon must be a number between -180 and 180',
    });
  }

  // Defaults
  const radiusKm = radius_km ? parseFloat(radius_km) : 10;
  const searchLimit = limit ? parseInt(limit) : 20;

  // Parse network_ids if provided
  const networkIdsArray = network_ids ? network_ids.split(',').map((id) => id.trim()) : [];

  // Get nearby locations
  const locations = getNearbyLocations(latitude, longitude, radiusKm, {
    network_ids: networkIdsArray,
    limit: searchLimit,
  });

  // Enrich with network names
  const enriched = locations.map((location) => {
    const network = getNetworkById(location.network_id);
    return {
      ...location,
      network_name: network ? network.name : '',
    };
  });

  return res.status(200).json({
    locations: enriched,
    count: enriched.length,
  });
}

module.exports = requireAuth(handler);
