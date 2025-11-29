-- Migration 010: Gift Card Balance Tracking
-- Add balance tracking fields to cards table and create history/receipt tables

-- Add balance fields to cards table
ALTER TABLE cards
ADD COLUMN current_balance NUMERIC(10,2),
ADD COLUMN balance_currency TEXT DEFAULT 'USD',
ADD COLUMN balance_last_updated TIMESTAMP;

-- Create balance history table to track changes over time
CREATE TABLE gift_card_balance_history (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  card_id TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  balance NUMERIC(10,2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'USD',
  notes TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create receipts table to store receipt images
CREATE TABLE gift_card_receipts (
  id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
  card_id TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  balance_history_id TEXT REFERENCES gift_card_balance_history(id) ON DELETE SET NULL,
  image_url TEXT NOT NULL,
  notes TEXT,
  purchase_date TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Create indexes for efficient queries
CREATE INDEX idx_balance_history_card_id ON gift_card_balance_history(card_id);
CREATE INDEX idx_balance_history_created_at ON gift_card_balance_history(created_at DESC);
CREATE INDEX idx_receipts_card_id ON gift_card_receipts(card_id);
CREATE INDEX idx_receipts_balance_history_id ON gift_card_receipts(balance_history_id);
CREATE INDEX idx_receipts_purchase_date ON gift_card_receipts(purchase_date DESC);

-- Add updated_at triggers
CREATE TRIGGER update_balance_history_updated_at
  BEFORE UPDATE ON gift_card_balance_history
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_receipts_updated_at
  BEFORE UPDATE ON gift_card_receipts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
