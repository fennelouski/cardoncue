/**
 * Shared brand name → domain mappings used by icon and brand resolution services.
 */

export const BRAND_DOMAIN_MAPPINGS: Record<string, string> = {
  costco: 'costco.com',
  'costco wholesale': 'costco.com',
  "sam's club": 'samsclub.com',
  'sams club': 'samsclub.com',
  "bj's": 'bjs.com',
  "bj's wholesale club": 'bjs.com',
  "bj's wholesale": 'bjs.com',
  bjs: 'bjs.com',
  'whole foods': 'wholefoodsmarket.com',
  'whole foods market': 'wholefoodsmarket.com',
  "trader joe's": 'traderjoes.com',
  'trader joes': 'traderjoes.com',
  "kohl's": 'kohls.com',
  kohls: 'kohls.com',
  "macy's": 'macys.com',
  macys: 'macys.com',
  target: 'target.com',
  walmart: 'walmart.com',
  cvs: 'cvs.com',
  'cvs pharmacy': 'cvs.com',
  walgreens: 'walgreens.com',
  'la fitness': 'lafitness.com',
  '24 hour fitness': '24hourfitness.com',
  'planet fitness': 'planetfitness.com',
  'anytime fitness': 'anytimefitness.com',
  "gold's gym": 'goldsgym.com',
  'golds gym': 'goldsgym.com',
  starbucks: 'starbucks.com',
  dunkin: 'dunkindonuts.com',
  "dunkin'": 'dunkindonuts.com',
  'dunkin donuts': 'dunkindonuts.com',
  kroger: 'kroger.com',
  safeway: 'safeway.com',
  albertsons: 'albertsons.com',
  publix: 'publix.com',
  'best buy': 'bestbuy.com',
  'home depot': 'homedepot.com',
  "lowe's": 'lowes.com',
  lowes: 'lowes.com',
  amc: 'amctheatres.com',
  'amc theatres': 'amctheatres.com',
  regal: 'regmovies.com',
  'regal cinemas': 'regmovies.com',
  cinemark: 'cinemark.com',
  panera: 'panerabread.com',
  'panera bread': 'panerabread.com',
  chipotle: 'chipotle.com',
  'h-e-b': 'heb.com',
  heb: 'heb.com',
  wegmans: 'wegmans.com',
  meijer: 'meijer.com',
  rei: 'rei.com',
  'dick\'s sporting goods': 'dickssportinggoods.com',
  petsmart: 'petsmart.com',
  petco: 'petco.com',
  "mcdonald's": 'mcdonalds.com',
  'chick-fil-a': 'chick-fil-a.com',
  subway: 'subway.com',
  shell: 'shell.com',
  chevron: 'chevron.com',
  '7-eleven': '7-eleven.com',
  equinox: 'equinox.com',
  ymca: 'ymca.org',
  crunch: 'crunch.com',
  'crunch fitness': 'crunch.com',
};

/**
 * Normalize a card or brand name for registry lookups.
 */
export function normalizeBrandName(name: string): string {
  return name
    .toLowerCase()
    .replace(/\s+(card|membership|rewards?|club|plus|prime|pass|member|loyalty|account|program)\s*$/gi, '')
    .replace(/[^a-z0-9]+/g, '')
    .trim();
}

/**
 * Normalize a display name key (keeps spaces for alias matching).
 */
export function normalizeBrandAlias(name: string): string {
  return name
    .toLowerCase()
    .replace(/\s+(card|membership|rewards?|club|plus|prime|pass|member|loyalty|account|program)\s*$/gi, '')
    .trim();
}

/**
 * Resolve a domain from a brand or card name.
 */
export function determineDomainForBrand(brandName: string): string {
  const aliasKey = normalizeBrandAlias(brandName);
  if (BRAND_DOMAIN_MAPPINGS[aliasKey]) {
    return BRAND_DOMAIN_MAPPINGS[aliasKey];
  }

  const normalized = normalizeBrandName(brandName);
  for (const [key, domain] of Object.entries(BRAND_DOMAIN_MAPPINGS)) {
    if (normalizeBrandName(key) === normalized) {
      return domain;
    }
  }

  const domain = aliasKey
    .replace(/\s+/g, '')
    .replace(/'/g, '')
    .replace(/-/g, '');

  return `${domain}.com`;
}

/**
 * Extract host from a website URL string.
 */
export function hostFromWebsite(website: string | null | undefined): string | null {
  if (!website) return null;
  try {
    const url = website.startsWith('http') ? website : `https://${website}`;
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return null;
  }
}
