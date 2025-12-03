-- Migration 015: Create Brand Locations Table
-- Brand locations represent physical places associated with card-issuing brands (e.g., specific library branches, store locations)

CREATE TABLE IF NOT EXISTS brand_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id UUID REFERENCES brands(id) ON DELETE CASCADE,

  -- Basic Information
  name TEXT NOT NULL,                           -- Location name (e.g., "Main Branch", "Downtown Store")
  address TEXT NOT NULL,                        -- Street address
  city TEXT,                                     -- City
  state TEXT,                                    -- State/Province
  zip_code TEXT,                                 -- ZIP/Postal code
  country TEXT DEFAULT 'US',                    -- Country code

  -- Coordinates
  latitude DECIMAL(10, 8) NOT NULL,            -- Latitude
  longitude DECIMAL(11, 8) NOT NULL,           -- Longitude

  -- Contact Information
  phone TEXT,                                    -- Phone number
  email TEXT,                                    -- Email address
  website TEXT,                                  -- Location-specific website

  -- Hours of Operation (stored as JSONB for flexibility)
  regular_hours JSONB,                          -- Weekly hours: {monday: {open: "09:00", close: "17:00"}, ...}
  special_hours JSONB,                          -- Special dates: [{date: "2024-12-25", status: "closed"}, ...]
  timezone TEXT DEFAULT 'America/New_York',    -- IANA timezone identifier

  -- External Integration
  place_id TEXT,                                 -- Google Maps Place ID

  -- Quality Control
  verified BOOLEAN DEFAULT FALSE,               -- Admin-verified location
  notes TEXT,                                    -- Admin notes

  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for fast lookups and geo queries
CREATE INDEX idx_brand_locations_brand_id ON brand_locations(brand_id);
CREATE INDEX idx_brand_locations_city ON brand_locations(city);
CREATE INDEX idx_brand_locations_state ON brand_locations(state);
CREATE INDEX idx_brand_locations_verified ON brand_locations(verified) WHERE verified = TRUE;

-- Geospatial index for nearby location queries
CREATE INDEX idx_brand_locations_coordinates ON brand_locations(latitude, longitude);

-- Updated timestamp trigger
CREATE OR REPLACE FUNCTION update_brand_locations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER brand_locations_updated_at_trigger
  BEFORE UPDATE ON brand_locations
  FOR EACH ROW
  EXECUTE FUNCTION update_brand_locations_updated_at();

-- Comments
COMMENT ON TABLE brand_locations IS 'Physical locations associated with card-issuing brands, with rich metadata';
COMMENT ON COLUMN brand_locations.regular_hours IS 'Weekly hours as JSON: {monday: {open: "09:00", close: "17:00"}}';
COMMENT ON COLUMN brand_locations.special_hours IS 'Special dates as JSON array: [{date: "2024-12-25", status: "closed"}]';
COMMENT ON COLUMN brand_locations.timezone IS 'IANA timezone for accurate hours display';
COMMENT ON COLUMN brand_locations.place_id IS 'Google Maps Place ID for integration';
