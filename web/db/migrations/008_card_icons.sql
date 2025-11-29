-- Migration 008: Add icon fields to cards table

-- Add icon columns to cards table
ALTER TABLE cards
ADD COLUMN IF NOT EXISTS default_icon_url TEXT,
ADD COLUMN IF NOT EXISTS custom_icon_url TEXT,
ADD COLUMN IF NOT EXISTS icon_blob_id TEXT;

-- Create index on icon columns for faster lookups
CREATE INDEX IF NOT EXISTS idx_cards_custom_icon ON cards(custom_icon_url) WHERE custom_icon_url IS NOT NULL;

-- Comments for documentation
COMMENT ON COLUMN cards.default_icon_url IS 'Auto-generated default icon URL based on card name/brand';
COMMENT ON COLUMN cards.custom_icon_url IS 'User-uploaded custom icon URL (overrides default)';
COMMENT ON COLUMN cards.icon_blob_id IS 'Vercel Blob ID for custom icon (for deletion)';
