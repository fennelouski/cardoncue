/**
 * GET /v1/cards/:card_id - Get card details
 * PATCH /v1/cards/:card_id - Update card metadata
 * DELETE /v1/cards/:card_id - Delete card (soft delete)
 */

const { requireAuth } = require('../../utils/auth');
const { getCardById, updateCard, deleteCard } = require('../../utils/db');

async function handleGet(req, res, cardId) {
  const userId = req.user.id;

  const card = getCardById(cardId, userId);
  if (!card) {
    return res.status(404).json({
      error: 'not_found',
      message: 'Card not found',
    });
  }

  return res.status(200).json(card);
}

async function handlePatch(req, res, cardId) {
  const userId = req.user.id;
  const { name, tags, network_ids, valid_from, valid_to, one_time, metadata } = req.body;

  // Build updates object (only include provided fields)
  const updates = {};
  if (name !== undefined) updates.name = name;
  if (tags !== undefined) updates.tags = tags;
  if (network_ids !== undefined) updates.network_ids = network_ids;
  if (valid_from !== undefined) updates.valid_from = valid_from;
  if (valid_to !== undefined) updates.valid_to = valid_to;
  if (one_time !== undefined) updates.one_time = one_time;
  if (metadata !== undefined) updates.metadata = metadata;

  const card = updateCard(cardId, userId, updates);
  if (!card) {
    return res.status(404).json({
      error: 'not_found',
      message: 'Card not found',
    });
  }

  return res.status(200).json(card);
}

async function handleDelete(req, res, cardId) {
  const userId = req.user.id;

  const success = deleteCard(cardId, userId);
  if (!success) {
    return res.status(404).json({
      error: 'not_found',
      message: 'Card not found',
    });
  }

  return res.status(204).send();
}

async function handler(req, res) {
  // Extract card_id from query or URL
  const cardId = req.query.card_id;

  if (!cardId) {
    return res.status(400).json({
      error: 'invalid_request',
      message: 'Missing card_id parameter',
    });
  }

  switch (req.method) {
    case 'GET':
      return handleGet(req, res, cardId);
    case 'PATCH':
      return handlePatch(req, res, cardId);
    case 'DELETE':
      return handleDelete(req, res, cardId);
    default:
      return res.status(405).json({ error: 'method_not_allowed', message: `Method ${req.method} not allowed` });
  }
}

module.exports = requireAuth(handler);
