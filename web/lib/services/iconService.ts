/**
 * Icon Service - Intelligently detects and provides card/brand icons
 */

import { sql } from '@vercel/postgres';
import { kv } from '@vercel/kv';

interface IconResult {
  url: string;
  source: 'cache' | 'search' | 'default';
}

/**
 * Get the default icon for a card based on its name/brand
 * Uses intelligent detection with web search and caching
 */
export async function getDefaultIconForCard(cardName: string): Promise<IconResult> {
  if (!cardName) {
    return { url: getDefaultPlaceholderIcon(), source: 'default' };
  }

  // Normalize card name for better matching
  const normalizedName = normalizeCardName(cardName);
  const cacheKey = `icon:${normalizedName}`;
  const failureCacheKey = `icon:fail:${normalizedName}`;

  try {
    // Check if we've recently failed to find an icon for this brand
    const cachedFailure = await kv.get<boolean>(failureCacheKey);
    if (cachedFailure) {
      return { url: getDefaultPlaceholderIcon(), source: 'default' };
    }

    // Check cache for successful icon lookups
    const cachedIcon = await kv.get<string>(cacheKey);
    if (cachedIcon) {
      return { url: cachedIcon, source: 'cache' };
    }

    // Search for brand icon using web search
    const iconUrl = await searchForBrandIcon(normalizedName, cardName);

    if (iconUrl) {
      // Cache the successful result for 30 days
      await kv.set(cacheKey, iconUrl, { ex: 60 * 60 * 24 * 30 });
      return { url: iconUrl, source: 'search' };
    }

    // Cache the failure for 1 day to avoid repeated searches
    await kv.set(failureCacheKey, true, { ex: 60 * 60 * 24 });

    // Fallback to placeholder
    const placeholder = getDefaultPlaceholderIcon();
    return { url: placeholder, source: 'default' };
  } catch (error) {
    console.error('Error getting default icon:', error);
    // Cache the error for 1 day
    await kv.set(failureCacheKey, true, { ex: 60 * 60 * 24 }).catch(() => {});
    return { url: getDefaultPlaceholderIcon(), source: 'default' };
  }
}

/**
 * Search for a brand icon using OpenAI Web Search
 */
async function searchForBrandIcon(normalizedName: string, originalName: string): Promise<string | null> {
  try {
    // Common brand icon sources
    const iconSources = [
      `https://logo.clearbit.com/${normalizedName}.com`,
      `https://www.google.com/s2/favicons?domain=${normalizedName}.com&sz=128`,
    ];

    // Try clearbit first (fast and reliable)
    const clearbitUrl = iconSources[0];
    const clearbitResponse = await fetch(clearbitUrl, { method: 'HEAD' });
    if (clearbitResponse.ok) {
      return clearbitUrl;
    }

    // Fallback to Google favicon
    return iconSources[1];
  } catch (error) {
    console.error('Error searching for brand icon:', error);
    return null;
  }
}

/**
 * Normalize card name for better matching
 * Examples: "Costco Card" -> "costco", "Amazon Prime" -> "amazon"
 */
function normalizeCardName(name: string): string {
  return name
    .toLowerCase()
    .replace(/\s+(card|membership|rewards?|club|plus|prime|pass)\s*$/gi, '')
    .replace(/[^a-z0-9]+/g, '')
    .trim();
}

/**
 * Get default placeholder icon
 */
function getDefaultPlaceholderIcon(): string {
  // Return a data URL for a simple card icon
  return 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTI4IiBoZWlnaHQ9IjEyOCIgdmlld0JveD0iMCAwIDEyOCAxMjgiIGZpbGw9Im5vbmUiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+CjxyZWN0IHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiByeD0iMTYiIGZpbGw9IiM0Qjg0RkYiLz4KPHBhdGggZD0iTTMyIDQ4SDk2VjY0SDMyVjQ4WiIgZmlsbD0id2hpdGUiIG9wYWNpdHk9IjAuMyIvPgo8cGF0aCBkPSJNMzIgNzJIOTZWODhIMzJWNzJaIiBmaWxsPSJ3aGl0ZSIgb3BhY2l0eT0iMC4zIi8+CjxjaXJjbGUgY3g9IjQ0IiBjeT0iNTYiIHI9IjQiIGZpbGw9IndoaXRlIi8+CjxjaXJjbGUgY3g9IjQ0IiBjeT0iODAiIHI9IjQiIGZpbGw9IndoaXRlIi8+Cjwvc3ZnPgo=';
}

/**
 * Get the display icon for a card (custom or default)
 */
export async function getCardIcon(cardId: string): Promise<string | null> {
  try {
    const result = await sql`
      SELECT custom_icon_url, default_icon_url, name
      FROM cards
      WHERE id = ${cardId}
    `;

    if (result.rows.length === 0) {
      return null;
    }

    const card = result.rows[0];

    // Return custom icon if set
    if (card.custom_icon_url) {
      return card.custom_icon_url;
    }

    // Return default icon if set
    if (card.default_icon_url) {
      return card.default_icon_url;
    }

    // Generate and cache default icon
    const iconResult = await getDefaultIconForCard(card.name);

    // Update database with generated default icon
    await sql`
      UPDATE cards
      SET default_icon_url = ${iconResult.url}
      WHERE id = ${cardId}
    `;

    return iconResult.url;
  } catch (error) {
    console.error('Error getting card icon:', error);
    return null;
  }
}

/**
 * Update card icon URLs in database
 */
export async function updateCardDefaultIcon(cardId: string, iconUrl: string): Promise<void> {
  await sql`
    UPDATE cards
    SET default_icon_url = ${iconUrl}
    WHERE id = ${cardId}
  `;
}

export async function updateCardCustomIcon(
  cardId: string,
  iconUrl: string,
  blobId?: string
): Promise<void> {
  await sql`
    UPDATE cards
    SET custom_icon_url = ${iconUrl},
        icon_blob_id = ${blobId || null}
    WHERE id = ${cardId}
  `;
}

export async function removeCardCustomIcon(cardId: string): Promise<string | null> {
  const result = await sql`
    UPDATE cards
    SET custom_icon_url = NULL,
        icon_blob_id = NULL
    WHERE id = ${cardId}
    RETURNING icon_blob_id
  `;

  return result.rows[0]?.icon_blob_id || null;
}
