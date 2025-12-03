-- Migration 009: Add gift card support with multi-merchant acceptance

-- Create gift_card_brands table
CREATE TABLE IF NOT EXISTS gift_card_brands (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    issuer TEXT NOT NULL,
    description TEXT,
    accepted_network_ids TEXT[] DEFAULT '{}',
    category TEXT,
    icon_url TEXT,
    auto_discovered BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add indexes for gift_card_brands
CREATE INDEX IF NOT EXISTS idx_gift_card_brands_accepted_networks ON gift_card_brands USING GIN(accepted_network_ids);
CREATE INDEX IF NOT EXISTS idx_gift_card_brands_issuer ON gift_card_brands(issuer);

-- Add gift card support columns to cards table
ALTER TABLE cards
ADD COLUMN IF NOT EXISTS card_type TEXT DEFAULT 'loyalty',
ADD COLUMN IF NOT EXISTS gift_card_brand_id TEXT REFERENCES gift_card_brands(id) ON DELETE SET NULL;

-- Create index for card_type and gift_card_brand_id
CREATE INDEX IF NOT EXISTS idx_cards_card_type ON cards(card_type);
CREATE INDEX IF NOT EXISTS idx_cards_gift_card_brand_id ON cards(gift_card_brand_id) WHERE gift_card_brand_id IS NOT NULL;

-- Add constraint to ensure card_type is one of the valid types
ALTER TABLE cards DROP CONSTRAINT IF EXISTS cards_card_type_check;
ALTER TABLE cards ADD CONSTRAINT cards_card_type_check
    CHECK (card_type IN ('loyalty', 'membership', 'gift_card', 'voucher', 'other'));

-- Comments for documentation
COMMENT ON TABLE gift_card_brands IS 'Gift card brands and which merchant networks accept them';
COMMENT ON COLUMN gift_card_brands.id IS 'Unique identifier for gift card brand (e.g., "red-lobster-gift-card")';
COMMENT ON COLUMN gift_card_brands.name IS 'Display name of the gift card brand (e.g., "Red Lobster Gift Card")';
COMMENT ON COLUMN gift_card_brands.issuer IS 'Company that issues the gift card (e.g., "Darden Restaurants")';
COMMENT ON COLUMN gift_card_brands.accepted_network_ids IS 'Array of network IDs where this gift card is accepted';
COMMENT ON COLUMN gift_card_brands.auto_discovered IS 'Whether accepting networks were discovered via AI';
COMMENT ON COLUMN cards.card_type IS 'Type of card: loyalty, membership, gift_card, voucher, or other';
COMMENT ON COLUMN cards.gift_card_brand_id IS 'Reference to gift_card_brands table if card_type is gift_card';
