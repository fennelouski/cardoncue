import { NextRequest, NextResponse } from 'next/server';
import { put, del } from '@vercel/blob';
import { sql } from '@vercel/postgres';
import { requireJwtAuth } from '@/lib/jwtAuth';
import { getCardIcon, updateCardCustomIcon, removeCardCustomIcon } from '@/lib/services/iconService';

/**
 * Confirm the card exists and belongs to the authenticated user.
 * Returns a response to short-circuit with, or null when access is allowed.
 */
async function denyIfNotOwner(
  cardId: string,
  userId: string
): Promise<NextResponse | null> {
  const cardCheck = await sql`
    SELECT id, user_id FROM cards WHERE id = ${cardId}
  `;

  if (cardCheck.rows.length === 0) {
    return NextResponse.json({ error: 'Card not found' }, { status: 404 });
  }

  if (cardCheck.rows[0].user_id !== userId) {
    return NextResponse.json(
      { error: 'Unauthorized: Card does not belong to this user' },
      { status: 403 }
    );
  }

  return null;
}

/**
 * GET /api/v1/cards/[cardId]/icon
 * Get the icon for a specific card
 */
export async function GET(
  request: NextRequest,
  { params }: { params: { cardId: string } }
) {
  try {
    const user = await requireJwtAuth(request);
    const { cardId } = params;

    if (!cardId) {
      return NextResponse.json({ error: 'Card ID is required' }, { status: 400 });
    }

    const denied = await denyIfNotOwner(cardId, user.id);
    if (denied) return denied;

    const iconUrl = await getCardIcon(cardId);

    if (!iconUrl) {
      return NextResponse.json({ error: 'Card not found' }, { status: 404 });
    }

    return NextResponse.json({
      cardId,
      iconUrl,
      success: true,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.includes('Unauthorized')) {
      return NextResponse.json({ error: message }, { status: 401 });
    }
    console.error('Error fetching card icon:', error);
    return NextResponse.json(
      { error: 'Failed to fetch card icon' },
      { status: 500 }
    );
  }
}

/**
 * POST /api/v1/cards/[cardId]/icon
 * Upload a custom icon for a card
 */
export async function POST(
  request: NextRequest,
  { params }: { params: { cardId: string } }
) {
  try {
    const user = await requireJwtAuth(request);
    const { cardId } = params;

    if (!cardId) {
      return NextResponse.json({ error: 'Card ID is required' }, { status: 400 });
    }

    const denied = await denyIfNotOwner(cardId, user.id);
    if (denied) return denied;

    const formData = await request.formData();
    const file = formData.get('icon') as File;

    if (!file) {
      return NextResponse.json({ error: 'Icon file is required' }, { status: 400 });
    }

    // Validate file type
    if (!file.type.startsWith('image/')) {
      return NextResponse.json({ error: 'File must be an image' }, { status: 400 });
    }

    // Validate file size (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
      return NextResponse.json({ error: 'File size must be less than 5MB' }, { status: 400 });
    }

    // Upload to Vercel Blob
    const blob = await put(`card-icons/${cardId}/${file.name}`, file, {
      access: 'public',
      addRandomSuffix: true,
    });

    // Update database with custom icon URL
    await updateCardCustomIcon(cardId, blob.url, blob.pathname);

    return NextResponse.json({
      cardId,
      iconUrl: blob.url,
      success: true,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.includes('Unauthorized')) {
      return NextResponse.json({ error: message }, { status: 401 });
    }
    console.error('Error uploading card icon:', error);
    return NextResponse.json(
      { error: 'Failed to upload card icon' },
      { status: 500 }
    );
  }
}

/**
 * DELETE /api/v1/cards/[cardId]/icon
 * Remove custom icon and revert to default
 */
export async function DELETE(
  request: NextRequest,
  { params }: { params: { cardId: string } }
) {
  try {
    const user = await requireJwtAuth(request);
    const { cardId } = params;

    if (!cardId) {
      return NextResponse.json({ error: 'Card ID is required' }, { status: 400 });
    }

    const denied = await denyIfNotOwner(cardId, user.id);
    if (denied) return denied;

    // Remove custom icon from database and get blob ID
    const blobId = await removeCardCustomIcon(cardId);

    // Delete from Vercel Blob storage if exists
    if (blobId) {
      try {
        await del(blobId);
      } catch (error) {
        console.error('Error deleting blob:', error);
        // Continue even if blob deletion fails
      }
    }

    // Get the default icon URL
    const defaultIconUrl = await getCardIcon(cardId);

    return NextResponse.json({
      cardId,
      iconUrl: defaultIconUrl,
      success: true,
      message: 'Custom icon removed, reverted to default',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : '';
    if (message.includes('Unauthorized')) {
      return NextResponse.json({ error: message }, { status: 401 });
    }
    console.error('Error removing card icon:', error);
    return NextResponse.json(
      { error: 'Failed to remove card icon' },
      { status: 500 }
    );
  }
}
