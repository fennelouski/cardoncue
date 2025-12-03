-- Migration 014: Create Brands Table
-- Brands represent companies/organizations that issue cards (e.g., Starbucks, Louisville Library)

CREATE TABLE IF NOT EXISTS brands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Brand Information
  name TEXT NOT NULL UNIQUE,                    -- Canonical name (lowercase, normalized)
  display_name TEXT NOT NULL,                   -- Display name (proper capitalization)
  description TEXT,                              -- Optional description
  logo_url TEXT,                                 -- URL to brand logo

  -- Contact Information
  website TEXT,                                  -- Brand website
  primary_email TEXT,                           -- Main contact email
  primary_phone TEXT,                           -- Main phone number

  -- Classification
  category TEXT,                                 -- e.g., "library", "retail", "restaurant", "theme_park"

  -- Quality Control
  verified BOOLEAN DEFAULT FALSE,               -- Admin-verified brand

  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for fast lookups
CREATE INDEX idx_brands_name ON brands(name);
CREATE INDEX idx_brands_category ON brands(category);
CREATE INDEX idx_brands_verified ON brands(verified) WHERE verified = TRUE;
CREATE INDEX idx_brands_display_name ON brands(display_name);

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_brands_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER brands_updated_at_trigger
  BEFORE UPDATE ON brands
  FOR EACH ROW
  EXECUTE FUNCTION update_brands_updated_at();

-- Comments
COMMENT ON TABLE brands IS 'Central registry of companies/organizations that issue cards';
COMMENT ON COLUMN brands.name IS 'Canonical name (lowercase, normalized) for matching';
COMMENT ON COLUMN brands.display_name IS 'Proper display name shown to users';
COMMENT ON COLUMN brands.category IS 'Type of business: library, retail, restaurant, theme_park, etc.';
COMMENT ON COLUMN brands.verified IS 'Admin-verified brand for high-confidence matching';
