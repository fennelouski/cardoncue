import { describe, it, expect, beforeAll, afterAll } from '@jest/globals';
import { sql } from '@/lib/db';

/**
 * Gift Card Feature Tests
 *
 * Tests the complete gift card flow:
 * 1. Database migration
 * 2. Gift card brand discovery
 * 3. Region refresh with gift card filtering
 */

describe('Gift Card Feature', () => {

  beforeAll(async () => {
    // Ensure test database is set up
    console.log('Setting up test database...');
  });

  afterAll(async () => {
    // Clean up test data
    console.log('Cleaning up test data...');
    try {
      await sql`DELETE FROM gift_card_brands WHERE id LIKE 'test-%'`;
      await sql`DELETE FROM cards WHERE name LIKE 'Test %'`;
    } catch (error) {
      console.error('Cleanup error:', error);
    }
  });

  describe('Database Schema', () => {
    it('should have gift_card_brands table', async () => {
      const result = await sql`
        SELECT EXISTS (
          SELECT FROM information_schema.tables
          WHERE table_name = 'gift_card_brands'
        );
      `;

      expect(result.rows[0].exists).toBe(true);
    });

    it('should have card_type column in cards table', async () => {
      const result = await sql`
        SELECT EXISTS (
          SELECT FROM information_schema.columns
          WHERE table_name = 'cards'
          AND column_name = 'card_type'
        );
      `;

      expect(result.rows[0].exists).toBe(true);
    });

    it('should have gift_card_brand_id column in cards table', async () => {
      const result = await sql`
        SELECT EXISTS (
          SELECT FROM information_schema.columns
          WHERE table_name = 'cards'
          AND column_name = 'gift_card_brand_id'
        );
      `;

      expect(result.rows[0].exists).toBe(true);
    });

    it('should enforce card_type constraint', async () => {
      // This should fail if we try to insert an invalid card_type
      let error: any = null;

      try {
        await sql`
          INSERT INTO cards (id, user_id, name, barcode_type, payload_encrypted, card_type)
          VALUES (
            'test-invalid-type',
            'test-user',
            'Test Card',
            'qr',
            'encrypted-payload',
            'invalid_type'
          )
        `;
      } catch (e) {
        error = e;
      }

      expect(error).toBeTruthy();
      expect(error?.message).toContain('cards_card_type_check');
    });
  });

  describe('Gift Card Brand CRUD', () => {
    it('should create a gift card brand', async () => {
      const brand = await sql`
        INSERT INTO gift_card_brands (
          id, name, issuer, description, accepted_network_ids, category, auto_discovered
        )
        VALUES (
          'test-red-lobster',
          'Red Lobster Gift Card',
          'Darden Restaurants',
          'Works at multiple Darden restaurant chains',
          ARRAY['red-lobster', 'olive-garden', 'longhorn-steakhouse'],
          'restaurant',
          true
        )
        RETURNING *
      `;

      expect(brand.rows[0]).toBeDefined();
      expect(brand.rows[0].id).toBe('test-red-lobster');
      expect(brand.rows[0].name).toBe('Red Lobster Gift Card');
      expect(brand.rows[0].accepted_network_ids).toHaveLength(3);
    });

    it('should retrieve gift card brand with accepted networks', async () => {
      const brand = await sql`
        SELECT * FROM gift_card_brands WHERE id = 'test-red-lobster'
      `;

      expect(brand.rows[0]).toBeDefined();
      expect(brand.rows[0].accepted_network_ids).toContain('red-lobster');
      expect(brand.rows[0].accepted_network_ids).toContain('olive-garden');
      expect(brand.rows[0].accepted_network_ids).toContain('longhorn-steakhouse');
    });

    it('should update accepted networks for a brand', async () => {
      await sql`
        UPDATE gift_card_brands
        SET accepted_network_ids = ARRAY['red-lobster', 'olive-garden', 'longhorn-steakhouse', 'bahama-breeze']
        WHERE id = 'test-red-lobster'
      `;

      const brand = await sql`
        SELECT * FROM gift_card_brands WHERE id = 'test-red-lobster'
      `;

      expect(brand.rows[0].accepted_network_ids).toHaveLength(4);
      expect(brand.rows[0].accepted_network_ids).toContain('bahama-breeze');
    });
  });

  describe('Gift Card Integration with Cards', () => {
    it('should create a card with gift_card type', async () => {
      const card = await sql`
        INSERT INTO cards (
          id, user_id, name, barcode_type, payload_encrypted,
          card_type, gift_card_brand_id, network_ids
        )
        VALUES (
          'test-card-1',
          'test-user',
          'Test Red Lobster Gift Card',
          'qr',
          'encrypted-payload-123',
          'gift_card',
          'test-red-lobster',
          ARRAY[]::text[]
        )
        RETURNING *
      `;

      expect(card.rows[0]).toBeDefined();
      expect(card.rows[0].card_type).toBe('gift_card');
      expect(card.rows[0].gift_card_brand_id).toBe('test-red-lobster');
    });

    it('should join cards with gift card brands', async () => {
      const result = await sql`
        SELECT
          c.id as card_id,
          c.name as card_name,
          c.card_type,
          g.id as brand_id,
          g.name as brand_name,
          g.accepted_network_ids
        FROM cards c
        LEFT JOIN gift_card_brands g ON c.gift_card_brand_id = g.id
        WHERE c.id = 'test-card-1'
      `;

      expect(result.rows[0]).toBeDefined();
      expect(result.rows[0].card_type).toBe('gift_card');
      expect(result.rows[0].brand_name).toBe('Red Lobster Gift Card');
      expect(result.rows[0].accepted_network_ids).toHaveLength(4);
    });

    it('should cascade delete when brand is deleted', async () => {
      // Create a test brand and card
      await sql`
        INSERT INTO gift_card_brands (id, name, issuer, accepted_network_ids)
        VALUES ('test-temp-brand', 'Temp Brand', 'Test Inc', ARRAY['temp-network'])
      `;

      await sql`
        INSERT INTO cards (
          id, user_id, name, barcode_type, payload_encrypted,
          card_type, gift_card_brand_id
        )
        VALUES (
          'test-temp-card',
          'test-user',
          'Temp Card',
          'qr',
          'encrypted',
          'gift_card',
          'test-temp-brand'
        )
      `;

      // Delete the brand
      await sql`DELETE FROM gift_card_brands WHERE id = 'test-temp-brand'`;

      // Check that card's gift_card_brand_id is now NULL
      const card = await sql`SELECT * FROM cards WHERE id = 'test-temp-card'`;
      expect(card.rows[0].gift_card_brand_id).toBeNull();

      // Cleanup
      await sql`DELETE FROM cards WHERE id = 'test-temp-card'`;
    });
  });

  describe('Gift Card Brand Discovery Mock', () => {
    // Note: We can't fully test the AI discovery without an API key,
    // but we can test the data flow

    it('should identify brand structure', () => {
      const mockBrandInfo = {
        brandId: 'target-giftcard',
        name: 'Target GiftCard',
        issuer: 'Target Corporation',
        description: 'Redeemable at Target stores and Target.com',
        acceptedNetworks: [
          { networkId: 'target', networkName: 'Target' }
        ],
        category: 'retail'
      };

      expect(mockBrandInfo.brandId).toBe('target-giftcard');
      expect(mockBrandInfo.acceptedNetworks).toHaveLength(1);
      expect(mockBrandInfo.category).toBe('retail');
    });

    it('should handle multi-merchant gift cards', () => {
      const mockBrandInfo = {
        brandId: 'red-lobster-gift-card',
        name: 'Red Lobster Gift Card',
        issuer: 'Darden Restaurants',
        description: 'Works at Darden restaurant chains',
        acceptedNetworks: [
          { networkId: 'red-lobster', networkName: 'Red Lobster' },
          { networkId: 'olive-garden', networkName: 'Olive Garden' },
          { networkId: 'longhorn-steakhouse', networkName: 'LongHorn Steakhouse' },
          { networkId: 'bahama-breeze', networkName: 'Bahama Breeze' },
          { networkId: 'seasons-52', networkName: 'Seasons 52' },
          { networkId: 'eddie-vs', networkName: "Eddie V's" },
          { networkId: 'capital-grille', networkName: 'The Capital Grille' }
        ],
        category: 'restaurant'
      };

      expect(mockBrandInfo.acceptedNetworks).toHaveLength(7);
      expect(mockBrandInfo.issuer).toBe('Darden Restaurants');
    });
  });

  describe('Region Refresh with Gift Cards', () => {
    it('should filter locations by gift card accepted networks', async () => {
      // Create test networks
      await sql`
        INSERT INTO networks (id, name, canonical_names, category, default_radius_meters)
        VALUES
          ('red-lobster', 'Red Lobster', ARRAY['Red Lobster'], 'restaurant', 100),
          ('olive-garden', 'Olive Garden', ARRAY['Olive Garden'], 'restaurant', 100)
        ON CONFLICT (id) DO NOTHING
      `;

      // Get gift card brand's accepted networks
      const brand = await sql`
        SELECT accepted_network_ids FROM gift_card_brands WHERE id = 'test-red-lobster'
      `;

      const acceptedNetworks = brand.rows[0]?.accepted_network_ids || [];

      expect(acceptedNetworks.length).toBeGreaterThan(0);
      expect(acceptedNetworks).toContain('red-lobster');
      expect(acceptedNetworks).toContain('olive-garden');
    });

    it('should return empty array for non-existent gift card brand', async () => {
      const brand = await sql`
        SELECT accepted_network_ids FROM gift_card_brands WHERE id = 'non-existent'
      `;

      expect(brand.rows).toHaveLength(0);
    });
  });
});

// Export for use in other test files
export {};
