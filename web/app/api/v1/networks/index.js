/**
 * GET /v1/networks - List all networks
 */

const { requireAuth } = require('../../utils/auth');
const { getAllNetworks } = require('../../utils/db');

async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'method_not_allowed', message: 'Only GET allowed' });
  }

  const { search, category } = req.query;

  const networks = getAllNetworks({ search, category });

  return res.status(200).json({
    networks,
    count: networks.length,
  });
}

module.exports = requireAuth(handler);
