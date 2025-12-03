import { Webhook } from 'svix';
import { headers } from 'next/headers';
import { WebhookEvent } from '@clerk/nextjs/server';
import { sql } from '@vercel/postgres';
import { NextResponse } from 'next/server';

/**
 * Clerk Webhook Handler
 *
 * Syncs Clerk user and subscription events to our PostgreSQL database
 *
 * Configure webhook in Clerk Dashboard:
 * 1. Go to Webhooks section
 * 2. Add endpoint: https://your-domain.com/api/webhooks/clerk
 * 3. Subscribe to events: user.*, subscription.*
 * 4. Copy signing secret to CLERK_WEBHOOK_SECRET env var
 */

export async function POST(req: Request) {
  const WEBHOOK_SECRET = process.env.CLERK_WEBHOOK_SECRET;

  if (!WEBHOOK_SECRET) {
    throw new Error('Missing CLERK_WEBHOOK_SECRET environment variable');
  }

  // Get headers
  const headerPayload = headers();
  const svix_id = headerPayload.get('svix-id');
  const svix_timestamp = headerPayload.get('svix-timestamp');
  const svix_signature = headerPayload.get('svix-signature');

  if (!svix_id || !svix_timestamp || !svix_signature) {
    return NextResponse.json(
      { error: 'Missing svix headers' },
      { status: 400 }
    );
  }

  // Get body
  const payload = await req.json();
  const body = JSON.stringify(payload);

  // Verify webhook signature
  const wh = new Webhook(WEBHOOK_SECRET);

  let evt: WebhookEvent;

  try {
    evt = wh.verify(body, {
      'svix-id': svix_id,
      'svix-timestamp': svix_timestamp,
      'svix-signature': svix_signature,
    }) as WebhookEvent;
  } catch (err) {
    console.error('Error verifying webhook:', err);
    return NextResponse.json(
      { error: 'Verification failed' },
      { status: 400 }
    );
  }

  // Handle event
  const eventType = evt.type;

  console.log(`📨 Webhook received: ${eventType}`);

  try {
    switch (eventType) {
      case 'user.created':
        await handleUserCreated(evt.data);
        break;

      case 'user.updated':
        await handleUserUpdated(evt.data);
        break;

      case 'user.deleted':
        await handleUserDeleted(evt.data);
        break;

      // Note: Subscription events would be handled separately if using
      // a billing provider like Stripe with webhooks to Clerk

      default:
        console.log(`Unhandled event type: ${eventType}`);
    }

    return NextResponse.json({ success: true }, { status: 200 });

  } catch (error) {
    console.error(`Error handling webhook ${eventType}:`, error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

// ==================== User Event Handlers ====================

async function handleUserCreated(data: any) {
  const userId = data.id;
  const email = data.email_addresses?.[0]?.email_address || null;
  const firstName = data.first_name || '';
  const lastName = data.last_name || '';
  const fullName = `${firstName} ${lastName}`.trim() || null;
  const clerkCreatedAt = new Date(data.created_at);

  console.log(`  Creating user: ${userId} (${email})`);

  await sql`
    INSERT INTO users (id, email, full_name, clerk_created_at)
    VALUES (
      ${userId},
      ${email},
      ${fullName},
      ${clerkCreatedAt.toISOString()}
    )
    ON CONFLICT (id) DO NOTHING
  `;

  // Log audit event
  await logAuditEvent({
    userId,
    action: 'user.created',
    resourceType: 'user',
    resourceId: userId,
    details: { email, fullName }
  });
}

async function handleUserUpdated(data: any) {
  const userId = data.id;
  const email = data.email_addresses?.[0]?.email_address || null;
  const firstName = data.first_name || '';
  const lastName = data.last_name || '';
  const fullName = `${firstName} ${lastName}`.trim() || null;

  console.log(`  Updating user: ${userId}`);

  await sql`
    UPDATE users SET
      email = ${email},
      full_name = ${fullName},
      updated_at = NOW()
    WHERE id = ${userId}
  `;

  await logAuditEvent({
    userId,
    action: 'user.updated',
    resourceType: 'user',
    resourceId: userId,
    details: { email, fullName }
  });
}

async function handleUserDeleted(data: any) {
  const userId = data.id;

  console.log(`  Deleting user: ${userId}`);

  // Soft delete: archive all cards first
  await sql`
    UPDATE cards SET
      archived_at = NOW()
    WHERE user_id = ${userId} AND archived_at IS NULL
  `;

  // Hard delete user (cascades to cards, region_cache, subscriptions via FK)
  await sql`
    DELETE FROM users WHERE id = ${userId}
  `;

  await logAuditEvent({
    userId,
    action: 'user.deleted',
    resourceType: 'user',
    resourceId: userId
  });
}

// ==================== Subscription Event Handlers ====================

// Note: Subscription handling would be implemented if using a separate
// billing provider (Stripe, etc.) with webhooks sent to Clerk

// ==================== Audit Logging ====================

interface AuditEvent {
  userId?: string;
  action: string;
  resourceType?: string;
  resourceId?: string;
  details?: any;
  ipAddress?: string;
  userAgent?: string;
}

async function logAuditEvent(event: AuditEvent) {
  try {
    await sql`
      INSERT INTO audit_log (
        user_id,
        action,
        resource_type,
        resource_id,
        details
      )
      VALUES (
        ${event.userId || null},
        ${event.action},
        ${event.resourceType || null},
        ${event.resourceId || null},
        ${JSON.stringify(event.details || {})}
      )
    `;
  } catch (error) {
    console.error('Failed to log audit event:', error);
    // Don't fail the webhook if audit logging fails
  }
}
