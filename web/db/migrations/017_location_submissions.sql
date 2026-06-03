-- Migration 017: Location submission queue fields on card_locations

ALTER TABLE card_locations
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'add_place',
  ADD COLUMN IF NOT EXISTS suggested_network_id TEXT,
  ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS reviewed_by TEXT,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
  ADD COLUMN IF NOT EXISTS approved_curated_key TEXT,
  ADD COLUMN IF NOT EXISTS report_count INTEGER NOT NULL DEFAULT 1;

-- Constrain status values
ALTER TABLE card_locations
  DROP CONSTRAINT IF EXISTS card_locations_status_check;

ALTER TABLE card_locations
  ADD CONSTRAINT card_locations_status_check
  CHECK (status IN ('pending', 'approved', 'rejected', 'duplicate'));

ALTER TABLE card_locations
  DROP CONSTRAINT IF EXISTS card_locations_source_check;

ALTER TABLE card_locations
  ADD CONSTRAINT card_locations_source_check
  CHECK (source IN ('add_place', 'manual_entry', 'card_location'));

CREATE INDEX IF NOT EXISTS idx_card_locations_status_created
  ON card_locations(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_card_locations_pending
  ON card_locations(created_at DESC)
  WHERE status = 'pending';

COMMENT ON COLUMN card_locations.status IS 'Submission workflow: pending, approved, rejected, duplicate';
COMMENT ON COLUMN card_locations.source IS 'iOS entry point: add_place, manual_entry, card_location';
COMMENT ON COLUMN card_locations.suggested_network_id IS 'Best-guess network id from card network_ids or metadata';
COMMENT ON COLUMN card_locations.approved_curated_key IS 'curated:networkId:lat:lon after admin approval';
COMMENT ON COLUMN card_locations.report_count IS 'Number of user reports for same place';
