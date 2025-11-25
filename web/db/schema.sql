-- CardOnCue Database Schema
-- PostgreSQL with basic geospatial support

-- Note: PostGIS not available on all providers
-- Using lat/lon columns with distance calculations instead

-- Users table (synced with Clerk)
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,                    -- Clerk user ID (user_...)
    email TEXT,
    full_name TEXT,
    clerk_created_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    preferences JSONB DEFAULT '{
        "sync_enabled": false,
        "notification_radius_meters": 100,
        "default_network_ids": []
    }'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Cards table with end-to-end encryption
CREATE TABLE IF NOT EXISTS cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    barcode_type TEXT NOT NULL CHECK (barcode_type IN ('qr', 'code128', 'pdf417', 'aztec', 'ean13', 'upc_a', 'code39', 'itf')),
    payload_encrypted TEXT NOT NULL,        -- Base64: "nonce:ciphertext:tag"
    tags TEXT[] DEFAULT '{}',
    network_ids TEXT[] DEFAULT '{}',
    valid_from TIMESTAMPTZ,
    valid_to TIMESTAMPTZ,
    one_time BOOLEAN DEFAULT false,
    used_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_cards_user_id ON cards(user_id);
CREATE INDEX IF NOT EXISTS idx_cards_network_ids ON cards USING GIN(network_ids);
CREATE INDEX IF NOT EXISTS idx_cards_tags ON cards USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_cards_archived ON cards(archived_at) WHERE archived_at IS NULL;

-- Networks table (chains of locations)
CREATE TABLE IF NOT EXISTS networks (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    canonical_names TEXT[] DEFAULT '{}',
    category TEXT NOT NULL CHECK (category IN ('grocery', 'retail', 'library', 'entertainment', 'one-time', 'other')),
    is_large_area BOOLEAN DEFAULT false,
    default_radius_meters INTEGER DEFAULT 100,
    tags TEXT[] DEFAULT '{}',
    logo_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_networks_category ON networks(category);
CREATE INDEX IF NOT EXISTS idx_networks_name ON networks(name);

-- Locations table with lat/lon columns
CREATE TABLE IF NOT EXISTS locations (
    id TEXT PRIMARY KEY,
    network_id TEXT NOT NULL REFERENCES networks(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    address TEXT,
    city TEXT,
    state TEXT,
    country TEXT DEFAULT 'US',
    postal_code TEXT,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    radius_meters INTEGER DEFAULT 100,
    phone TEXT,
    hours JSONB,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_locations_network_id ON locations(network_id);
CREATE INDEX IF NOT EXISTS idx_locations_lat_lon ON locations(latitude, longitude);

-- Haversine distance function (in meters)
CREATE OR REPLACE FUNCTION haversine_distance(
    lat1 DOUBLE PRECISION,
    lon1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lon2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION AS $$
DECLARE
    R CONSTANT DOUBLE PRECISION := 6371000; -- Earth radius in meters
    dLat DOUBLE PRECISION;
    dLon DOUBLE PRECISION;
    a DOUBLE PRECISION;
    c DOUBLE PRECISION;
BEGIN
    dLat := radians(lat2 - lat1);
    dLon := radians(lon2 - lon1);

    a := sin(dLat/2) * sin(dLat/2) +
         cos(radians(lat1)) * cos(radians(lat2)) *
         sin(dLon/2) * sin(dLon/2);

    c := 2 * atan2(sqrt(a), sqrt(1-a));

    RETURN R * c;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Region cache for iOS optimization (stores last refresh state)
CREATE TABLE IF NOT EXISTS region_cache (
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    regions JSONB NOT NULL,                    -- Array of monitored regions
    last_refresh_lat DOUBLE PRECISION,
    last_refresh_lon DOUBLE PRECISION,
    last_refresh_at TIMESTAMPTZ NOT NULL,
    cache_ttl_seconds INTEGER DEFAULT 21600,  -- 6 hours
    PRIMARY KEY (user_id)
);

CREATE INDEX IF NOT EXISTS idx_region_cache_refresh_at ON region_cache(last_refresh_at);

-- Subscriptions (synced from Clerk webhooks)
CREATE TABLE IF NOT EXISTS subscriptions (
    id TEXT PRIMARY KEY,                       -- Clerk subscription ID
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('active', 'canceled', 'past_due', 'trialing', 'incomplete')),
    plan_id TEXT NOT NULL,                     -- 'free', 'premium', etc.
    current_period_start TIMESTAMPTZ,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);

-- Audit log for admin actions
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT,
    action TEXT NOT NULL,
    resource_type TEXT,
    resource_id TEXT,
    details JSONB DEFAULT '{}'::jsonb,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON audit_log(created_at DESC);

-- ==================== Row-Level Security ====================

-- Enable RLS on user-specific tables
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE region_cache ENABLE ROW LEVEL SECURITY;

-- Function to get current user ID (set by API middleware)
CREATE OR REPLACE FUNCTION current_user_id() RETURNS TEXT AS $$
    SELECT NULLIF(current_setting('app.current_user_id', true), '')::TEXT;
$$ LANGUAGE SQL STABLE;

-- Policy: Users can only access their own cards
DROP POLICY IF EXISTS cards_isolation ON cards;
CREATE POLICY cards_isolation ON cards
    FOR ALL
    USING (user_id = current_user_id());

-- Policy: Users can only access their own region cache
DROP POLICY IF EXISTS region_cache_isolation ON region_cache;
CREATE POLICY region_cache_isolation ON region_cache
    FOR ALL
    USING (user_id = current_user_id());

-- ==================== Helper Functions ====================

-- Get nearby locations using Haversine distance
CREATE OR REPLACE FUNCTION get_nearby_locations(
    search_lat DOUBLE PRECISION,
    search_lon DOUBLE PRECISION,
    search_radius_meters INTEGER DEFAULT 10000,
    limit_count INTEGER DEFAULT 20
)
RETURNS TABLE(
    id TEXT,
    network_id TEXT,
    name TEXT,
    address TEXT,
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION,
    radius_meters INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        l.id,
        l.network_id,
        l.name,
        l.address,
        l.latitude::DOUBLE PRECISION,
        l.longitude::DOUBLE PRECISION,
        haversine_distance(search_lat, search_lon, l.latitude::DOUBLE PRECISION, l.longitude::DOUBLE PRECISION),
        l.radius_meters
    FROM locations l
    WHERE haversine_distance(search_lat, search_lon, l.latitude::DOUBLE PRECISION, l.longitude::DOUBLE PRECISION) <= search_radius_meters
    ORDER BY 7
    FETCH FIRST limit_count ROWS ONLY;
END;
$$ LANGUAGE plpgsql;

-- Get top K regions for monitoring (implements nearest-K algorithm)
CREATE OR REPLACE FUNCTION get_top_regions(
    search_lat DOUBLE PRECISION,
    search_lon DOUBLE PRECISION,
    user_networks TEXT[],
    radius_km DOUBLE PRECISION DEFAULT 50.0,
    max_regions INTEGER DEFAULT 20
)
RETURNS TABLE(
    id TEXT,
    network_id TEXT,
    network_name TEXT,
    name TEXT,
    address TEXT,
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    radius_meters INTEGER,
    priority INTEGER,
    distance_meters DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    WITH nearby AS (
        SELECT
            l.id,
            l.network_id,
            n.name AS network_name,
            l.name,
            l.address,
            l.latitude::DOUBLE PRECISION AS lat,
            l.longitude::DOUBLE PRECISION AS lon,
            l.radius_meters,
            CASE
                WHEN l.network_id = ANY(user_networks) THEN 1
                ELSE 2
            END AS priority,
            haversine_distance(search_lat, search_lon, l.latitude::DOUBLE PRECISION, l.longitude::DOUBLE PRECISION) AS distance_meters
        FROM locations l
        JOIN networks n ON l.network_id = n.id
        WHERE haversine_distance(search_lat, search_lon, l.latitude::DOUBLE PRECISION, l.longitude::DOUBLE PRECISION) <= radius_km * 1000
    )
    SELECT * FROM nearby
    ORDER BY 9, 10  -- priority (col 9), distance_meters (col 10)
    FETCH FIRST max_regions ROWS ONLY;
END;
$$ LANGUAGE plpgsql;

-- ==================== Triggers ====================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_cards_updated_at ON cards;
CREATE TRIGGER update_cards_updated_at
    BEFORE UPDATE ON cards
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_networks_updated_at ON networks;
CREATE TRIGGER update_networks_updated_at
    BEFORE UPDATE ON networks
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_locations_updated_at ON locations;
CREATE TRIGGER update_locations_updated_at
    BEFORE UPDATE ON locations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_subscriptions_updated_at ON subscriptions;
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ==================== Views ====================

-- Active cards view (excludes archived)
CREATE OR REPLACE VIEW active_cards AS
SELECT * FROM cards
WHERE archived_at IS NULL;

-- Active subscriptions view
CREATE OR REPLACE VIEW active_subscriptions AS
SELECT * FROM subscriptions
WHERE status = 'active'
AND current_period_end > NOW();

-- Network stats view
CREATE OR REPLACE VIEW network_stats AS
SELECT
    n.id,
    n.name,
    n.category,
    COUNT(l.id) AS location_count,
    COUNT(DISTINCT c.user_id) AS user_count
FROM networks n
LEFT JOIN locations l ON n.id = l.network_id
LEFT JOIN cards c ON n.id = ANY(c.network_ids)
WHERE c.archived_at IS NULL
GROUP BY n.id, n.name, n.category;

-- ==================== Sample Data Functions ====================

-- Function to seed a network with locations
CREATE OR REPLACE FUNCTION seed_network(
    network_id TEXT,
    network_name TEXT,
    network_category TEXT,
    locations_json JSONB
) RETURNS VOID AS $$
BEGIN
    -- Insert network
    INSERT INTO networks (id, name, canonical_names, category)
    VALUES (
        network_id,
        network_name,
        ARRAY[network_name],
        network_category
    )
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        updated_at = NOW();

    -- Insert locations
    INSERT INTO locations (id, network_id, name, address, latitude, longitude, radius_meters)
    SELECT
        loc->>'id',
        network_id,
        loc->>'name',
        loc->>'address',
        (loc->>'lat')::DECIMAL(10, 8),
        (loc->>'lon')::DECIMAL(11, 8),
        COALESCE((loc->>'radius')::INTEGER, 100)
    FROM jsonb_array_elements(locations_json) AS loc
    ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        address = EXCLUDED.address,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;
