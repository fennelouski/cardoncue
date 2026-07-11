/**
 * Logo.dev provider — drop-in replacement for the sunset Clearbit Logo API.
 */

import { determineDomainForBrand, hostFromWebsite } from './brandDomainMappings';

const LOGO_DEV_BASE = 'https://img.logo.dev';

export type LogoSource = 'logo_api' | 'favicon' | 'none';

export interface LogoFetchResult {
  url: string | null;
  domain: string;
  source: LogoSource;
}

function logoDevUrl(domain: string): string {
  const token = process.env.LOGO_DEV_TOKEN;
  const base = `${LOGO_DEV_BASE}/${domain}`;
  return token ? `${base}?token=${encodeURIComponent(token)}` : base;
}

/**
 * Build a Logo.dev URL for a domain (does not verify availability).
 */
export function buildLogoDevUrl(domain: string): string {
  return logoDevUrl(domain);
}

/**
 * Resolve domain from brand name and/or website.
 */
export function resolveDomain(brandName: string, website?: string | null): string {
  const websiteHost = hostFromWebsite(website);
  if (websiteHost) {
    return websiteHost;
  }
  return determineDomainForBrand(brandName);
}

/**
 * Fetch a brand logo, trying Logo.dev first then Google favicons.
 */
export async function fetchBrandLogo(
  brandName: string,
  website?: string | null
): Promise<LogoFetchResult> {
  const domain = resolveDomain(brandName, website);
  const logoDev = logoDevUrl(domain);

  try {
    const response = await fetch(logoDev, { method: 'HEAD', redirect: 'follow' });
    if (response.ok) {
      return { url: logoDev, domain, source: 'logo_api' };
    }
  } catch (error) {
    console.warn('[logoProvider] Logo.dev HEAD failed:', error);
  }

  try {
    const response = await fetch(logoDev, { method: 'GET', redirect: 'follow' });
    if (response.ok && (response.headers.get('content-type') || '').startsWith('image/')) {
      return { url: logoDev, domain, source: 'logo_api' };
    }
  } catch (error) {
    console.warn('[logoProvider] Logo.dev GET failed:', error);
  }

  const faviconUrl = `https://www.google.com/s2/favicons?domain=${domain}&sz=128`;
  return { url: faviconUrl, domain, source: 'favicon' };
}
