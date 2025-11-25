-- Import Queue Table for Location Data
-- Manages automated imports from OpenStreetMap and other sources

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS import_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  network_id TEXT NOT NULL,
  network_name TEXT NOT NULL,
  priority INTEGER DEFAULT 100,  -- Lower number = higher priority
  status TEXT DEFAULT 'pending', -- pending, processing, completed, failed

  -- Import parameters
  latitude DECIMAL(10, 8),       -- Optional: specific location to search near
  longitude DECIMAL(11, 8),
  radius_km INTEGER DEFAULT 100, -- Search radius in kilometers

  -- Tracking
  attempts INTEGER DEFAULT 0,
  last_attempted_at TIMESTAMP WITH TIME ZONE,
  last_error TEXT,
  locations_found INTEGER DEFAULT 0,
  locations_inserted INTEGER DEFAULT 0,
  data_source TEXT,              -- openstreetmap, google-places, ai-discovery

  -- Metadata
  added_by TEXT,                 -- user_id or 'system'
  added_reason TEXT,             -- 'manual', 'card_created', 'scheduled', 'initial'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,

  CONSTRAINT fk_network FOREIGN KEY (network_id) REFERENCES networks(id) ON DELETE CASCADE
);

-- Indexes for efficient queue processing
CREATE INDEX IF NOT EXISTS idx_import_queue_status ON import_queue(status);
CREATE INDEX IF NOT EXISTS idx_import_queue_priority ON import_queue(priority, created_at);
CREATE INDEX IF NOT EXISTS idx_import_queue_network ON import_queue(network_id);
CREATE INDEX IF NOT EXISTS idx_import_queue_next_pending ON import_queue(status, priority, created_at)
  WHERE status = 'pending';

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_import_queue_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_import_queue_updated_at
  BEFORE UPDATE ON import_queue
  FOR EACH ROW
  EXECUTE FUNCTION update_import_queue_updated_at();

-- View for queue statistics
CREATE OR REPLACE VIEW import_queue_stats AS
SELECT
  status,
  COUNT(*) as count,
  AVG(locations_found) as avg_locations_found,
  AVG(attempts) as avg_attempts,
  MIN(created_at) as oldest_item,
  MAX(updated_at) as most_recent_update
FROM import_queue
GROUP BY status;

COMMENT ON TABLE import_queue IS 'Queue for automated location imports from OpenStreetMap and other sources';
COMMENT ON COLUMN import_queue.priority IS 'Lower number = higher priority. 1-10: critical, 11-50: high, 51-100: normal, 101+: low';
COMMENT ON COLUMN import_queue.status IS 'pending: not yet processed, processing: currently running, completed: successfully imported, failed: import failed';
