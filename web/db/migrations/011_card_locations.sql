-- Migration 011: Add card_locations table for tracking user-reported locations

-- Create card_locations table
CREATE TABLE IF NOT EXISTS card_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    card_id UUID NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    location_name TEXT NOT NULL,
    address TEXT,
    city TEXT,
    state TEXT,
    country TEXT,
    postal_code TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add indexes for card_locations
CREATE INDEX IF NOT EXISTS idx_card_locations_card_id ON card_locations(card_id);
CREATE INDEX IF NOT EXISTS idx_card_locations_user_id ON card_locations(user_id);
CREATE INDEX IF NOT EXISTS idx_card_locations_created_at ON card_locations(created_at DESC);

-- Add index for geographic queries (if needed in the future)
CREATE INDEX IF NOT EXISTS idx_card_locations_coordinates
    ON card_locations(latitude, longitude)
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Comments for documentation
COMMENT ON TABLE card_locations IS 'User-reported locations where cards are accepted or used';
COMMENT ON COLUMN card_locations.id IS 'Unique identifier for the location report';
COMMENT ON COLUMN card_locations.card_id IS 'Reference to the card that was used at this location';
COMMENT ON COLUMN card_locations.user_id IS 'User who reported this location';
COMMENT ON COLUMN card_locations.location_name IS 'Name of the location (e.g., "Starbucks", "Whole Foods")';
COMMENT ON COLUMN card_locations.address IS 'Street address of the location';
COMMENT ON COLUMN card_locations.latitude IS 'Latitude coordinate of the location';
COMMENT ON COLUMN card_locations.longitude IS 'Longitude coordinate of the location';
COMMENT ON COLUMN card_locations.notes IS 'Optional notes from the user about this location';
