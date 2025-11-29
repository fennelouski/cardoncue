import { NextResponse } from 'next/server';
import { sql } from '@vercel/postgres';

// Force this route to be dynamic (runtime only, not build time)
export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';

/**
 * Admin endpoint to run card icon migration
 * GET /api/admin/migrate-icons
 */
export async function GET() {
  try {
    console.log('Starting card icon migration...');

    // Add the columns if they don't exist
    await sql`
      ALTER TABLE cards
      ADD COLUMN IF NOT EXISTS default_icon_url TEXT,
      ADD COLUMN IF NOT EXISTS custom_icon_url TEXT,
      ADD COLUMN IF NOT EXISTS icon_blob_id TEXT
    `;

    // Add index
    await sql`
      CREATE INDEX IF NOT EXISTS idx_cards_custom_icon
      ON cards(custom_icon_url)
      WHERE custom_icon_url IS NOT NULL
    `;

    // Add comments
    await sql`
      COMMENT ON COLUMN cards.default_icon_url IS 'Auto-generated default icon URL based on card name/brand'
    `;
    await sql`
      COMMENT ON COLUMN cards.custom_icon_url IS 'User-uploaded custom icon URL (overrides default)'
    `;
    await sql`
      COMMENT ON COLUMN cards.icon_blob_id IS 'Vercel Blob ID for custom icon (for deletion)'
    `;

    // Verify the columns were created
    const result = await sql`
      SELECT column_name, data_type
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'cards'
        AND column_name IN ('default_icon_url', 'custom_icon_url', 'icon_blob_id')
    `;

    if (result.rows.length === 3) {
      return NextResponse.json({
        success: true,
        message: 'Card icon columns added successfully',
        columns: result.rows,
      });
    } else {
      return NextResponse.json({
        success: false,
        message: 'Column verification failed',
        columns: result.rows,
      }, { status: 500 });
    }
  } catch (error: any) {
    console.error('Migration failed:', error);
    return NextResponse.json({
      success: false,
      message: 'Migration failed',
      error: error.message,
    }, { status: 500 });
  }
}
