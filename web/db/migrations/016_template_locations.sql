-- Migration 016: Template-Brand Location Associations and Card Templates Update

-- 1. Create many-to-many relationship between templates and brand locations
CREATE TABLE IF NOT EXISTS template_brand_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID REFERENCES card_templates(id) ON DELETE CASCADE,
  brand_location_id UUID REFERENCES brand_locations(id) ON DELETE CASCADE,
  priority INT DEFAULT 0,                       -- Lower = higher priority (shown first)
  created_at TIMESTAMP DEFAULT NOW(),

  UNIQUE(template_id, brand_location_id)
);

-- Indexes for fast lookups
CREATE INDEX idx_template_brand_locations_template ON template_brand_locations(template_id);
CREATE INDEX idx_template_brand_locations_location ON template_brand_locations(brand_location_id);
CREATE INDEX idx_template_brand_locations_priority ON template_brand_locations(priority);

-- Comments
COMMENT ON TABLE template_brand_locations IS 'Many-to-many relationship between card templates and brand locations';
COMMENT ON COLUMN template_brand_locations.priority IS 'Display priority: 0 = highest, shown first to users';

-- 2. Add new columns to card_templates table
ALTER TABLE card_templates
  ADD COLUMN IF NOT EXISTS brand_id UUID REFERENCES brands(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS default_brand_location_id UUID REFERENCES brand_locations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS notes TEXT;

-- Indexes for new foreign keys
CREATE INDEX IF NOT EXISTS idx_card_templates_brand ON card_templates(brand_id);
CREATE INDEX IF NOT EXISTS idx_card_templates_default_brand_location ON card_templates(default_brand_location_id);

-- Comments
COMMENT ON COLUMN card_templates.brand_id IS 'Reference to brand/company that issues this card';
COMMENT ON COLUMN card_templates.default_brand_location_id IS 'Optional default/primary brand location for this template';
COMMENT ON COLUMN card_templates.notes IS 'Admin notes about this template';
