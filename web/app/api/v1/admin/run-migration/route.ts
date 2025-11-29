import { NextRequest, NextResponse } from 'next/server';
import { sql, pool } from '@/lib/db';
import fs from 'fs';
import path from 'path';

/**
 * Admin endpoint to run database migrations
 * POST /api/v1/admin/run-migration
 */
export async function POST(req: NextRequest) {
  try {
    const { migration } = await req.json();

    if (!migration) {
      return NextResponse.json(
        { error: 'migration parameter required (e.g., "009_gift_cards")' },
        { status: 400 }
      );
    }

    console.log(`[Migration] Running migration: ${migration}`);

    // Read the migration file
    const migrationPath = path.join(process.cwd(), 'db', 'migrations', `${migration}.sql`);

    if (!fs.existsSync(migrationPath)) {
      return NextResponse.json(
        { error: 'migration_not_found', message: `Migration file not found: ${migration}.sql` },
        { status: 404 }
      );
    }

    const migrationSQL = fs.readFileSync(migrationPath, 'utf-8');

    // Execute the migration
    console.log('[Migration] Executing SQL...');

    // Split on semicolons and filter empty statements
    const statements = migrationSQL
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0 && !s.startsWith('--'));

    for (const statement of statements) {
      try {
        await pool.query(statement);
      } catch (error: any) {
        // Ignore "already exists" errors
        if (!error.message.includes('already exists')) {
          throw error;
        }
        console.log('[Migration] Skipping already exists:', error.message);
      }
    }

    console.log('[Migration] Verifying changes...');

    // Verify the changes for gift cards migration
    if (migration === '009_gift_cards') {
      const checks = await sql`
        SELECT
          (SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'gift_card_brands')) as brands_table,
          (SELECT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'cards' AND column_name = 'card_type')) as card_type,
          (SELECT EXISTS (SELECT FROM information_schema.columns WHERE table_name = 'cards' AND column_name = 'gift_card_brand_id')) as brand_id
      `;

      return NextResponse.json({
        ok: true,
        migration,
        message: 'Migration completed successfully',
        verification: {
          gift_card_brands_table: checks.rows[0].brands_table,
          cards_card_type_column: checks.rows[0].card_type,
          cards_gift_card_brand_id_column: checks.rows[0].brand_id,
        },
      });
    }

    return NextResponse.json({
      ok: true,
      migration,
      message: 'Migration completed successfully',
    });

  } catch (error: any) {
    console.error('[Migration] Error:', error);
    return NextResponse.json(
      {
        error: 'migration_failed',
        message: error.message,
        stack: error.stack,
      },
      { status: 500 }
    );
  }
}

// GET endpoint to list available migrations
export async function GET() {
  try {
    const migrationsDir = path.join(process.cwd(), 'db', 'migrations');

    if (!fs.existsSync(migrationsDir)) {
      return NextResponse.json({
        ok: true,
        migrations: [],
        message: 'No migrations directory found',
      });
    }

    const files = fs.readdirSync(migrationsDir);
    const migrations = files
      .filter(f => f.endsWith('.sql'))
      .map(f => f.replace('.sql', ''));

    return NextResponse.json({
      ok: true,
      migrations,
      count: migrations.length,
    });

  } catch (error: any) {
    return NextResponse.json(
      { error: 'failed_to_list_migrations', message: error.message },
      { status: 500 }
    );
  }
}
