/**
 * Icon Service - Intelligently detects and provides card/brand icons
 */

import { sql } from '@vercel/postgres';
import { kv } from '@vercel/kv';
import { normalizeBrandName } from './brandDomainMappings';
import { fetchBrandLogo } from './logoProvider';
import { resolveBrand } from './brandService';

interface IconResult {
  url: string;
  source: 'cache' | 'registry' | 'logo_api' | 'favicon' | 'default';
}

/**
 * Get the default icon for a card based on its name/brand
 */
export async function getDefaultIconForCard(cardName: string): Promise<IconResult> {
  if (!cardName) {
    return { url: getDefaultPlaceholderIcon(), source: 'default' };
  }

  const normalizedName = normalizeBrandName(cardName);
  const cacheKey = `icon:${normalizedName}`;
  const failureCacheKey = `icon:fail:${normalizedName}`;

  try {
    const cachedFailure = await kv.get<boolean>(failureCacheKey);
    if (cachedFailure) {
      return { url: getDefaultPlaceholderIcon(), source: 'default' };
    }

    const cachedIcon = await kv.get<string>(cacheKey);
    if (cachedIcon) {
      return { url: cachedIcon, source: 'cache' };
    }

    const resolved = await resolveBrand({ name: cardName });

    if (resolved.logoUrl) {
      await kv.set(cacheKey, resolved.logoUrl, { ex: 60 * 60 * 24 * 30 });
      return {
        url: resolved.logoUrl,
        source:
          resolved.source === 'registry'
            ? 'registry'
            : resolved.source === 'logo_api'
              ? 'logo_api'
              : 'favicon',
      };
    }

    const domainResult = await fetchBrandLogo(cardName);
    if (domainResult.url) {
      await kv.set(cacheKey, domainResult.url, { ex: 60 * 60 * 24 * 30 });
      return {
        url: domainResult.url,
        source: domainResult.source === 'logo_api' ? 'logo_api' : 'favicon',
      };
    }

    await kv.set(failureCacheKey, true, { ex: 60 * 60 * 24 });
    return { url: getDefaultPlaceholderIcon(), source: 'default' };
  } catch (error) {
    console.error('Error getting default icon:', error);
    await kv.set(failureCacheKey, true, { ex: 60 * 60 * 24 }).catch(() => {});
    return { url: getDefaultPlaceholderIcon(), source: 'default' };
  }
}

/**
 * Normalize card name for better matching
 */
export function normalizeCardName(name: string): string {
  return normalizeBrandName(name);
}

/**
 * Get default placeholder icon
 */
function getDefaultPlaceholderIcon(): string {
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

    if (card.custom_icon_url) {
      return card.custom_icon_url;
    }

    if (card.default_icon_url) {
      return card.default_icon_url;
    }

    const iconResult = await getDefaultIconForCard(card.name);

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
