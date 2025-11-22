/**
 * GET /v1/cards - List user's cards
 * POST /v1/cards - Create a new card
 */

const { requireAuth } = require('../../utils/auth');
const { getCardsByUser, createCard } = require('../../utils/db');

async function handleGet(req, res) {
  const userId = req.user.id;

  const options = {
    include_archived: req.query.include_archived === 'true',
    network_id: req.query.network_id,
  };

  const cards = getCardsByUser(userId, options);

  return res.status(200).json({
    cards,
    count: cards.length,
  });
}

async function handlePost(req, res) {
  const userId = req.user.id;
  const { name, barcode_type, payload_encrypted, tags, network_ids, valid_from, valid_to, one_time, metadata } = req.body;

  // Validate required fields
  if (!name || !barcode_type || !payload_encrypted) {
    return res.status(400).json({
      error: 'invalid_request',
      message: 'Missing required fields: name, barcode_type, payload_encrypted',
    });
  }

  // Validate barcode_type
  const validBarcodeTypes = ['qr', 'code128', 'pdf417', 'aztec', 'ean13', 'upc_a', 'code39', 'itf'];
  if (!validBarcodeTypes.includes(barcode_type)) {
    return res.status(400).json({
      error: 'invalid_request',
      message: `Invalid barcode_type. Must be one of: ${validBarcodeTypes.join(', ')}`,
    });
  }

  // Create card
  const card = createCard(userId, {
    name,
    barcode_type,
    payload_encrypted,
    tags,
    network_ids,
    valid_from,
    valid_to,
    one_time,
    metadata,
  });

  return res.status(201).json(card);
}

async function handler(req, res) {
  switch (req.method) {
    case 'GET':
      return handleGet(req, res);
    case 'POST':
      return handlePost(req, res);
    default:
      return res.status(405).json({ error: 'method_not_allowed', message: `Method ${req.method} not allowed` });
  }
}

module.exports = requireAuth(handler);
