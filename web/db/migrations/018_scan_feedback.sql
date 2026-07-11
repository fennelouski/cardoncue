-- Migration 018: Add scan_feedback table for "did it scan?" user feedback

CREATE TABLE IF NOT EXISTS scan_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id UUID NOT NULL UNIQUE,
    device_id TEXT,
    user_id TEXT,
    card_id TEXT NOT NULL,
    barcode_type TEXT,
    worked BOOLEAN NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scan_feedback_card_id ON scan_feedback(card_id);
CREATE INDEX IF NOT EXISTS idx_scan_feedback_worked ON scan_feedback(worked);
CREATE INDEX IF NOT EXISTS idx_scan_feedback_created_at ON scan_feedback(created_at DESC);

COMMENT ON TABLE scan_feedback IS 'User feedback on whether an in-app barcode scanned at the register';
COMMENT ON COLUMN scan_feedback.submission_id IS 'Client-generated UUID; unique so a thumb tap + later note upsert into one row';
COMMENT ON COLUMN scan_feedback.card_id IS 'Local card UUID (no FK; telemetry only)';
COMMENT ON COLUMN scan_feedback.worked IS 'true = scanned fine, false = did not scan';
COMMENT ON COLUMN scan_feedback.note IS 'Optional free-text detail added via "Tell us more"';
