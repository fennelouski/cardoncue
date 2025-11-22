/**
 * POST /v1/auth/apple
 * Authenticate with Sign in with Apple
 */

const { generateTokens } = require('../../utils/auth');
const { createUser, getUserByAppleId } = require('../../utils/db');

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'method_not_allowed', message: 'Only POST allowed' });
  }

  const { identity_token, user_identifier, email, full_name } = req.body;

  // Validate required fields
  if (!identity_token) {
    return res.status(400).json({
      error: 'invalid_request',
      message: 'Missing required field: identity_token',
    });
  }

  // TODO: Validate identity_token with Apple servers
  // For development, we'll skip this step and use user_identifier directly
  console.log('[DEV] Skipping Apple token validation');

  if (!user_identifier) {
    return res.status(400).json({
      error: 'invalid_request',
      message: 'Missing required field: user_identifier (dev mode)',
    });
  }

  // Check if user exists
  let user = getUserByAppleId(user_identifier);

  if (!user) {
    // Create new user
    user = createUser({
      email: email || `${user_identifier}@privaterelay.appleid.com`,
      full_name: full_name
        ? `${full_name.given_name || ''} ${full_name.family_name || ''}`.trim()
        : null,
      identity_provider: 'apple',
      apple_user_id: user_identifier,
    });

    console.log(`Created new user: ${user.id}`);
  }

  // Generate tokens
  const tokens = generateTokens(user.id, user.email);

  // Return response
  return res.status(200).json({
    ...tokens,
    user: {
      id: user.id,
      email: user.email,
      full_name: user.full_name,
      created_at: user.created_at,
      preferences: user.preferences,
    },
  });
};
