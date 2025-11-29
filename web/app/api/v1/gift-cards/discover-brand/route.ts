import { NextRequest, NextResponse } from 'next/server';
import Anthropic from '@anthropic-ai/sdk';
import { sql, pool } from '@/lib/db';

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

interface DiscoverBrandRequest {
  cardName: string;
  barcode?: string;
  metadata?: Record<string, string>;
}

interface GiftCardBrandInfo {
  brandId: string;
  name: string;
  issuer: string;
  description: string;
  acceptedNetworks: Array<{
    networkId: string;
    networkName: string;
  }>;
  category: string;
}

export async function POST(req: NextRequest) {
  try {
    const body: DiscoverBrandRequest = await req.json();
    const { cardName, barcode, metadata } = body;

    if (!cardName) {
      return NextResponse.json(
        { error: 'card_name is required' },
        { status: 400 }
      );
    }

    console.log(`[Gift Card Discovery] Analyzing: ${cardName}`);

    // Use Claude to identify the gift card brand and accepting merchants
    const brandInfo = await discoverGiftCardBrand(cardName, barcode, metadata);

    if (!brandInfo) {
      return NextResponse.json(
        { error: 'could_not_identify_brand', message: 'Unable to identify gift card brand' },
        { status: 404 }
      );
    }

    // Check if brand already exists
    const existingBrand = await sql`
      SELECT * FROM gift_card_brands WHERE id = ${brandInfo.brandId}
    `;

    let brand;

    if (existingBrand.rows.length > 0) {
      // Update existing brand
      // Build network IDs array for SQL
      const networkIds = brandInfo.acceptedNetworks.map(n => n.networkId);

      const updated = await pool.query(
        `UPDATE gift_card_brands
         SET
           name = $1,
           issuer = $2,
           description = $3,
           accepted_network_ids = $4,
           category = $5,
           auto_discovered = true,
           updated_at = NOW()
         WHERE id = $6
         RETURNING *`,
        [brandInfo.name, brandInfo.issuer, brandInfo.description, networkIds, brandInfo.category, brandInfo.brandId]
      );
      brand = updated.rows[0];
      console.log(`[Gift Card Discovery] Updated existing brand: ${brandInfo.brandId}`);
    } else {
      // Create new brand
      const networkIds = brandInfo.acceptedNetworks.map(n => n.networkId);

      const inserted = await pool.query(
        `INSERT INTO gift_card_brands (
           id, name, issuer, description, accepted_network_ids, category, auto_discovered
         )
         VALUES ($1, $2, $3, $4, $5, $6, true)
         RETURNING *`,
        [brandInfo.brandId, brandInfo.name, brandInfo.issuer, brandInfo.description, networkIds, brandInfo.category]
      );
      brand = inserted.rows[0];
      console.log(`[Gift Card Discovery] Created new brand: ${brandInfo.brandId}`);
    }

    // Ensure all accepting networks exist in the networks table
    await ensureNetworksExist(brandInfo.acceptedNetworks);

    return NextResponse.json({
      ok: true,
      brand: {
        id: brand.id,
        name: brand.name,
        issuer: brand.issuer,
        description: brand.description,
        acceptedNetworkIds: brand.accepted_network_ids,
        category: brand.category,
        autoDiscovered: brand.auto_discovered,
      },
      acceptedNetworks: brandInfo.acceptedNetworks,
    });
  } catch (error: any) {
    console.error('[Gift Card Discovery] Error:', error);
    return NextResponse.json(
      { error: 'internal_error', message: error.message },
      { status: 500 }
    );
  }
}

async function discoverGiftCardBrand(
  cardName: string,
  barcode?: string,
  metadata?: Record<string, string>
): Promise<GiftCardBrandInfo | null> {
  const prompt = `You are a gift card expert. Analyze the following gift card and provide detailed information about it.

Gift Card Name: ${cardName}
${barcode ? `Barcode: ${barcode}` : ''}
${metadata ? `Additional Info: ${JSON.stringify(metadata)}` : ''}

Please identify:
1. The exact brand name of this gift card
2. The company that issues this gift card
3. ALL merchants/restaurant chains that accept this gift card (be comprehensive - many gift cards work at multiple locations)
4. A brief description of the gift card program
5. The category (restaurant, retail, entertainment, multi-purpose, etc.)

For example:
- A "Red Lobster Gift Card" is issued by Darden Restaurants and works at Red Lobster, Olive Garden, LongHorn Steakhouse, Bahama Breeze, Seasons 52, Eddie V's, and The Capital Grille
- A "Target GiftCard" only works at Target stores
- A "Visa Gift Card" works at any merchant that accepts Visa

Respond in JSON format:
{
  "brandId": "kebab-case-brand-id",
  "name": "Official Brand Name",
  "issuer": "Issuing Company",
  "description": "Brief description",
  "acceptedNetworks": [
    {"networkId": "network-id", "networkName": "Network Display Name"}
  ],
  "category": "restaurant|retail|entertainment|multi-purpose"
}

If you cannot identify this as a real gift card brand, respond with: {"error": "unknown_brand"}`;

  try {
    const message = await anthropic.messages.create({
      model: 'claude-sonnet-4-5-20250929',
      max_tokens: 2000,
      messages: [
        {
          role: 'user',
          content: prompt,
        },
      ],
    });

    const responseText = message.content[0].type === 'text'
      ? message.content[0].text
      : '';

    // Extract JSON from response
    const jsonMatch = responseText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.error('[Gift Card Discovery] No JSON found in response');
      return null;
    }

    const result = JSON.parse(jsonMatch[0]);

    if (result.error === 'unknown_brand') {
      return null;
    }

    return result as GiftCardBrandInfo;
  } catch (error) {
    console.error('[Gift Card Discovery] AI error:', error);
    return null;
  }
}

async function ensureNetworksExist(networks: Array<{ networkId: string; networkName: string }>) {
  for (const network of networks) {
    await sql`
      INSERT INTO networks (id, name, canonical_names, category, default_radius_meters)
      VALUES (
        ${network.networkId},
        ${network.networkName},
        ARRAY[${network.networkName}],
        'restaurant',
        100
      )
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        updated_at = NOW()
    `;
  }
}
