/**
 * Brand resolution service — tiered lookup: registry → logo API → favicon.
 */

import { sql, pool } from '@/lib/db';
import { kv } from '@vercel/kv';
import {
  determineDomainForBrand,
  hostFromWebsite,
  normalizeBrandAlias,
  normalizeBrandName,
} from './brandDomainMappings';
import { fetchBrandLogo } from './logoProvider';

export type BrandResolveSource = 'cache' | 'registry' | 'logo_api' | 'favicon' | 'none';
export type BrandResolveTier = 1 | 2 | 3 | 4;

export interface BrandResolveResult {
  name: string;
  displayName: string;
  category: string | null;
  domain: string;
  logoUrl: string | null;
  source: BrandResolveSource;
  tier: BrandResolveTier;
  verified: boolean;
}

interface RegistryRow {
  id: string;
  name: string;
  display_name: string;
  category: string | null;
  logo_url: string | null;
  website: string | null;
  verified: boolean;
}

function cacheKeyFor(name: string, website?: string | null): string {
  const normalized = normalizeBrandName(name);
  const host = hostFromWebsite(website);
  return host ? `brand:resolve:${normalized}:${host}` : `brand:resolve:${normalized}`;
}

async function lookupRegistry(
  name: string,
  website?: string | null
): Promise<RegistryRow | null> {
  const normalized = normalizeBrandName(name);
  const alias = normalizeBrandAlias(name);
  const host = hostFromWebsite(website);

  const byName = await pool.query<RegistryRow>(
    `
    SELECT id, name, display_name, category, logo_url, website, verified
    FROM brands
    WHERE name = $1 OR name = $2
    LIMIT 1
    `,
    [normalized, alias.replace(/[^a-z0-9]+/g, '')]
  );

  if (byName.rows.length > 0) {
    return byName.rows[0];
  }

  if (host) {
    const byWebsite = await pool.query<RegistryRow>(
      `
      SELECT id, name, display_name, category, logo_url, website, verified
      FROM brands
      WHERE website ILIKE $1 OR website ILIKE $2
      LIMIT 1
      `,
      [`%${host}%`, `%www.${host}%`]
    );
    if (byWebsite.rows.length > 0) {
      return byWebsite.rows[0];
    }
  }

  const byDisplay = await pool.query<RegistryRow>(
    `
    SELECT id, name, display_name, category, logo_url, website, verified
    FROM brands
    WHERE LOWER(display_name) = $1
    LIMIT 1
    `,
    [alias]
  );

  return byDisplay.rows[0] ?? null;
}

async function upsertUnverifiedBrand(params: {
  name: string;
  displayName: string;
  domain: string;
  logoUrl: string;
  category?: string | null;
}): Promise<void> {
  const normalized = normalizeBrandName(params.displayName);
  await pool.query(
    `
    INSERT INTO brands (name, display_name, logo_url, website, category, verified)
    VALUES ($1, $2, $3, $4, $5, false)
    ON CONFLICT (name) DO UPDATE SET
      logo_url = COALESCE(brands.logo_url, EXCLUDED.logo_url),
      website = COALESCE(brands.website, EXCLUDED.website),
      updated_at = NOW()
    `,
    [
      normalized,
      params.displayName,
      params.logoUrl,
      `https://${params.domain}`,
      params.category ?? null,
    ]
  );
}

/**
 * Resolve a brand icon using the tiered pipeline.
 */
export async function resolveBrand(params: {
  name: string;
  website?: string | null;
  locationName?: string | null;
}): Promise<BrandResolveResult> {
  const lookupName = params.locationName?.trim() || params.name.trim();
  if (!lookupName) {
    const domain = determineDomainForBrand('');
    return {
      name: '',
      displayName: '',
      category: null,
      domain,
      logoUrl: null,
      source: 'none',
      tier: 4,
      verified: false,
    };
  }

  const key = cacheKeyFor(lookupName, params.website);

  try {
    const cached = await kv.get<BrandResolveResult>(key);
    if (cached) {
      return { ...cached, source: 'cache' };
    }
  } catch {
    // KV unavailable — continue without cache
  }

  const registry = await lookupRegistry(lookupName, params.website);
  const domain =
    hostFromWebsite(registry?.website) ||
    hostFromWebsite(params.website) ||
    determineDomainForBrand(lookupName);

  if (registry?.logo_url) {
    const result: BrandResolveResult = {
      name: registry.name,
      displayName: registry.display_name,
      category: registry.category,
      domain,
      logoUrl: registry.logo_url,
      source: 'registry',
      tier: 1,
      verified: registry.verified,
    };
    await cacheResolveResult(key, result);
    return result;
  }

  const logoResult = await fetchBrandLogo(lookupName, params.website ?? registry?.website);
  if (logoResult.source === 'logo_api' && logoResult.url) {
    const displayName = registry?.display_name ?? lookupName;
    await upsertUnverifiedBrand({
      name: normalizeBrandName(displayName),
      displayName,
      domain: logoResult.domain,
      logoUrl: logoResult.url,
      category: registry?.category ?? null,
    });

    const result: BrandResolveResult = {
      name: registry?.name ?? normalizeBrandName(displayName),
      displayName,
      category: registry?.category ?? null,
      domain: logoResult.domain,
      logoUrl: logoResult.url,
      source: 'logo_api',
      tier: 2,
      verified: false,
    };
    await cacheResolveResult(key, result);
    return result;
  }

  if (logoResult.url && logoResult.source === 'favicon') {
    const displayName = registry?.display_name ?? lookupName;
    const result: BrandResolveResult = {
      name: registry?.name ?? normalizeBrandName(displayName),
      displayName,
      category: registry?.category ?? null,
      domain: logoResult.domain,
      logoUrl: logoResult.url,
      source: 'favicon',
      tier: 3,
      verified: registry?.verified ?? false,
    };
    await cacheResolveResult(key, result);
    return result;
  }

  const result: BrandResolveResult = {
    name: registry?.name ?? normalizeBrandName(lookupName),
    displayName: registry?.display_name ?? lookupName,
    category: registry?.category ?? null,
    domain,
    logoUrl: null,
    source: 'none',
    tier: 4,
    verified: registry?.verified ?? false,
  };
  await cacheResolveResult(key, result, 60 * 60 * 24);
  return result;
}

async function cacheResolveResult(
  key: string,
  result: BrandResolveResult,
  ttlSeconds = 60 * 60 * 24 * 30
): Promise<void> {
  try {
    await kv.set(key, result, { ex: ttlSeconds });
  } catch {
    // Ignore cache write failures
  }
}

/**
 * List verified brands for iOS offline snapshot sync.
 */
export async function listBrandSnapshot(limit = 200): Promise<
  Array<{
    name: string;
    displayName: string;
    domain: string;
    category: string | null;
    logoUrl: string | null;
    verified: boolean;
  }>
> {
  const result = await sql`
    SELECT name, display_name, logo_url, website, category, verified
    FROM brands
    WHERE verified = true OR logo_url IS NOT NULL
    ORDER BY verified DESC, display_name ASC
    LIMIT ${limit}
  `;

  return result.rows.map((row) => ({
    name: row.name as string,
    displayName: row.display_name as string,
    domain:
      hostFromWebsite(row.website as string | null) ??
      determineDomainForBrand(row.display_name as string),
    category: (row.category as string | null) ?? null,
    logoUrl: (row.logo_url as string | null) ?? null,
    verified: Boolean(row.verified),
  }));
}

/**
 * Seed brands from import queue and prefetch logos into brands.logo_url.
 */
export async function seedBrandLogos(
  brands: Array<{ name: string; category: string }>
): Promise<{ seeded: number; logosFound: number; failures: string[] }> {
  let seeded = 0;
  let logosFound = 0;
  const failures: string[] = [];

  for (const brand of brands) {
    const normalized = normalizeBrandName(brand.name);
    const domain = determineDomainForBrand(brand.name);

    try {
      const existing = await pool.query(
        'SELECT id, logo_url FROM brands WHERE name = $1 LIMIT 1',
        [normalized]
      );

      if (existing.rows.length === 0) {
        await pool.query(
          `
          INSERT INTO brands (name, display_name, website, category, verified)
          VALUES ($1, $2, $3, $4, false)
          ON CONFLICT (name) DO NOTHING
          `,
          [normalized, brand.name, `https://${domain}`, brand.category]
        );
        seeded++;
      }

      if (existing.rows[0]?.logo_url) {
        logosFound++;
        continue;
      }

      const logo = await fetchBrandLogo(brand.name);
      if (logo.url && logo.source === 'logo_api') {
        await pool.query(
          `
          UPDATE brands
          SET logo_url = $1, website = COALESCE(website, $2), updated_at = NOW()
          WHERE name = $3
          `,
          [logo.url, `https://${logo.domain}`, normalized]
        );
        logosFound++;
      } else {
        failures.push(brand.name);
      }

      await new Promise((resolve) => setTimeout(resolve, 100));
    } catch (error: any) {
      failures.push(`${brand.name}: ${error.message}`);
    }
  }

  return { seeded, logosFound, failures };
}
