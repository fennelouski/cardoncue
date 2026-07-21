import { NextRequest } from 'next/server';
import jwt from 'jsonwebtoken';

// Never fall back to a hardcoded secret: an unset JWT_SECRET must reject all tokens,
// not verify them against a value that is public in source control.
const JWT_SECRET = process.env.JWT_SECRET;

export interface AuthenticatedUser {
  id: string;
  email?: string;
}

export function extractBearerToken(request: NextRequest): string | null {
  const authHeader = request.headers.get('authorization');
  if (!authHeader) return null;

  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') return null;

  return parts[1];
}

export function verifyAccessToken(token: string): AuthenticatedUser | null {
  if (!JWT_SECRET) {
    // Fail closed rather than authenticate against a missing/insecure secret.
    console.error('JWT_SECRET is not configured; rejecting all access tokens.');
    return null;
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] }) as {
      sub?: string;
      email?: string;
      type?: string;
    };

    if (decoded.type !== 'access' || !decoded.sub) {
      return null;
    }

    return {
      id: decoded.sub,
      email: decoded.email,
    };
  } catch {
    return null;
  }
}

/**
 * Require a valid iOS/API JWT access token (Sign in with Apple flow).
 */
export async function requireJwtAuth(request: NextRequest): Promise<AuthenticatedUser> {
  const token = extractBearerToken(request);
  if (!token) {
    throw new Error('Unauthorized: Missing or invalid Authorization header');
  }

  const user = verifyAccessToken(token);
  if (!user) {
    throw new Error('Unauthorized: Invalid or expired access token');
  }

  return user;
}
