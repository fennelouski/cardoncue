import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { pool } from '@/lib/db'

export const runtime = 'nodejs'

// GET /api/v1/profile - Get user profile
export async function GET(request: NextRequest) {
  try {
    const { userId } = await auth()

    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const result = await pool.query(
      'SELECT * FROM user_profiles WHERE id = $1',
      [userId]
    )

    if (result.rows.length === 0) {
      return NextResponse.json({ error: 'Profile not found' }, { status: 404 })
    }

    return NextResponse.json(result.rows[0])
  } catch (error) {
    console.error('Error fetching profile:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}

// PUT /api/v1/profile - Update user profile
export async function PUT(request: NextRequest) {
  try {
    const { userId } = await auth()

    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    const { display_name, preferences } = body

    // Upsert user profile
    const result = await pool.query(
      `INSERT INTO user_profiles (id, display_name, preferences, updated_at)
       VALUES ($1, $2, $3, NOW())
       ON CONFLICT (id)
       DO UPDATE SET
         display_name = EXCLUDED.display_name,
         preferences = EXCLUDED.preferences,
         updated_at = NOW()
       RETURNING *`,
      [userId, display_name, JSON.stringify(preferences)]
    )

    return NextResponse.json(result.rows[0])
  } catch (error) {
    console.error('Error updating profile:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
