/**
 * Authentication middleware and utilities
 */

const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-production';
const ACCESS_TOKEN_EXPIRY = '15m';
const REFRESH_TOKEN_EXPIRY = '7d';

/**
 * Generate access and refresh tokens
 */
function generateTokens(userId, email) {
  const accessToken = jwt.sign(
    {
      sub: userId,
      email: email,
      type: 'access',
    },
    JWT_SECRET,
    { expiresIn: ACCESS_TOKEN_EXPIRY }
  );

  const refreshToken = jwt.sign(
    {
      sub: userId,
      type: 'refresh',
    },
    JWT_SECRET,
    { expiresIn: REFRESH_TOKEN_EXPIRY }
  );

  return {
    access_token: accessToken,
    refresh_token: refreshToken,
    expires_in: 900, // 15 minutes in seconds
    token_type: 'Bearer',
  };
}

/**
 * Verify JWT token
 */
function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    return null;
  }
}

/**
 * Extract bearer token from Authorization header
 */
function extractBearerToken(req) {
  const authHeader = req.headers.authorization || req.headers.Authorization;
  if (!authHeader) {
    return null;
  }

  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return null;
  }

  return parts[1];
}

/**
 * Middleware: Require authentication
 */
function requireAuth(handler) {
  return async (req, res) => {
    // Extract token
    const token = extractBearerToken(req);
    if (!token) {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'Missing or invalid Authorization header',
      });
    }

    // Verify token
    const decoded = verifyToken(token);
    if (!decoded) {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'Invalid or expired access token',
      });
    }

    // Check token type
    if (decoded.type !== 'access') {
      return res.status(401).json({
        error: 'unauthorized',
        message: 'Invalid token type (expected access token)',
      });
    }

    // Attach user to request
    req.user = {
      id: decoded.sub,
      email: decoded.email,
    };

    // Call handler
    return handler(req, res);
  };
}

/**
 * Middleware: Require admin role
 */
function requireAdmin(handler) {
  return requireAuth(async (req, res) => {
    // TODO: Check if user has admin role in database
    // For now, simple check based on email domain
    if (!req.user.email.endsWith('@cardoncue.app')) {
      return res.status(403).json({
        error: 'forbidden',
        message: 'Admin access required',
      });
    }

    return handler(req, res);
  });
}

module.exports = {
  generateTokens,
  verifyToken,
  extractBearerToken,
  requireAuth,
  requireAdmin,
};
