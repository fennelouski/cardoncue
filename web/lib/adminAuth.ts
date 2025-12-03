import { auth } from '@clerk/nextjs/server';
import { clerkClient } from '@clerk/nextjs/server';

export interface AdminUser {
  userId: string;
  email: string;
}

/**
 * Middleware to require admin authentication for dashboard routes
 * Only allows users with @100apps.studio email domain
 */
export async function requireAdminAuth(): Promise<AdminUser> {
  const { userId } = await auth();

  if (!userId) {
    throw new Error('Unauthorized: Authentication required');
  }

  // Get user from Clerk
  const user = await clerkClient().users.getUser(userId);
  const email = user.emailAddresses[0]?.emailAddress;

  if (!email) {
    throw new Error('Unauthorized: No email address found');
  }

  if (!email.endsWith('@100apps.studio')) {
    throw new Error('Forbidden: Admin access required');
  }

  return { userId, email };
}

/**
 * Helper to check if a user has admin access without throwing
 */
export async function isAdmin(): Promise<boolean> {
  try {
    await requireAdminAuth();
    return true;
  } catch {
    return false;
  }
}
