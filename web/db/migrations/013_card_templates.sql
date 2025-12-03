-- Card Templates: Store card signatures and metadata for intelligent auto-fill
-- This allows the system to recognize previously scanned cards and auto-apply metadata

CREATE TABLE IF NOT EXISTS card_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Card signature/fingerprint
  image_hash TEXT NOT NULL,           -- Perceptual hash of card front image
  text_signature TEXT,                -- Normalized text extracted from card

  -- Card metadata
  card_name TEXT NOT NULL,            -- e.g., "Louisville Free Public Library"
  card_type TEXT,                     -- membership, loyalty, giftCard, etc.

  -- Location metadata
  location_name TEXT,                 -- e.g., "Main Library"
  location_address TEXT,              -- Full address
  location_lat DECIMAL(10, 8),        -- Latitude
  location_lng DECIMAL(11, 8),        -- Longitude

  -- Quality and usage metrics
  confidence_score DECIMAL(3, 2) DEFAULT 0.5,  -- 0.0-1.0 confidence in this template
  usage_count INT DEFAULT 1,                   -- Number of times this template has been used
  verified BOOLEAN DEFAULT FALSE,              -- Admin-verified template

  -- Metadata
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  -- Multiple designs for same location support
  design_variant TEXT,                -- Optional: to handle multiple card designs for same location

  -- Constraints
  CONSTRAINT card_templates_confidence_check CHECK (confidence_score >= 0 AND confidence_score <= 1)
);

-- Indexes for fast lookups
CREATE INDEX idx_card_templates_image_hash ON card_templates(image_hash);
CREATE INDEX idx_card_templates_text_signature ON card_templates(text_signature);
CREATE INDEX idx_card_templates_card_name ON card_templates(card_name);
CREATE INDEX idx_card_templates_usage_count ON card_templates(usage_count DESC);
CREATE INDEX idx_card_templates_verified ON card_templates(verified) WHERE verified = TRUE;

-- Composite index for matching queries
CREATE INDEX idx_card_templates_lookup ON card_templates(image_hash, text_signature, verified);

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_card_templates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER card_templates_updated_at_trigger
  BEFORE UPDATE ON card_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_card_templates_updated_at();

-- Comments for documentation
COMMENT ON TABLE card_templates IS 'Stores card signatures and metadata for intelligent auto-fill across users';
COMMENT ON COLUMN card_templates.image_hash IS 'Perceptual hash of card front image for visual matching';
COMMENT ON COLUMN card_templates.text_signature IS 'Normalized OCR text for text-based matching';
COMMENT ON COLUMN card_templates.confidence_score IS 'Quality score (0.0-1.0) indicating template reliability';
COMMENT ON COLUMN card_templates.usage_count IS 'Number of times users have matched this template';
COMMENT ON COLUMN card_templates.verified IS 'Admin-verified template for high-confidence matches';
COMMENT ON COLUMN card_templates.design_variant IS 'Identifier for handling multiple card designs for same location';
