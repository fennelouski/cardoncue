/**
 * POST /v1/region-refresh
 * Get top K nearest locations for iOS region monitoring
 */

const { requireAuth } = require('../utils/auth');
const { getTopRegions } = require('../utils/db');

async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'method_not_allowed', message: 'Only POST allowed' });
  }

  const { lat, lon, accuracy, radius_km, user_networks, max_regions } = req.body;

  // Validate required fields
  if (lat === undefined || lon === undefined) {
    return res.status(400).json({
      error: 'invalid_request',
      message: 'Missing required fields: lat, lon',
    });
  }

  // Validate ranges
  if (lat < -90 || lat > 90) {
    return res.status(400).json({
      error: 'invalid_request',
      message: 'lat must be between -90 and 90',
    });
  }

  if (lon < -180 || lon > 180) {
    return res.status(400).json({
      error: 'invalid_request',
      message: 'lon must be between -180 and 180',
    });
  }

  // Defaults
  const radiusKm = radius_km || 50;
  const maxRegions = max_regions || 20;
  const userNetworks = user_networks || [];

  // Validate max_regions
  if (maxRegions < 1 || maxRegions > 20) {
    return res.status(400).json({
      error: 'invalid_request',
      message: 'max_regions must be between 1 and 20',
    });
  }

  // Get top regions
  const regions = getTopRegions(lat, lon, radiusKm, userNetworks, maxRegions);

  // Return response
  return res.status(200).json({
    regions,
    refresh_after_meters: 500,
    cache_ttl_seconds: 21600, // 6 hours
    server_time: new Date().toISOString(),
  });
}

module.exports = requireAuth(handler);
