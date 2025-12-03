import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@clerk/nextjs/server'
import { put } from '@vercel/blob'
import { pool } from '@/lib/db'

export const runtime = 'nodejs'

// POST /api/v1/profile/picture - Upload profile picture
export async function POST(request: NextRequest) {
  try {
    const { userId } = await auth()

    if (!userId) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const formData = await request.formData()
    const file = formData.get('file') as File

    if (!file) {
      return NextResponse.json({ error: 'No file provided' }, { status: 400 })
    }

    // Validate file type
    if (!file.type.startsWith('image/')) {
      return NextResponse.json({ error: 'File must be an image' }, { status: 400 })
    }

    // Validate file size (5MB max)
    if (file.size > 5 * 1024 * 1024) {
      return NextResponse.json(
        { error: 'File size must be less than 5MB' },
        { status: 400 }
      )
    }

    // Upload to Vercel Blob
    const blob = await put(`profile-pictures/${userId}-${Date.now()}.${file.type.split('/')[1]}`, file, {
      access: 'public',
    })

    // Update user profile with new picture URL
    const result = await pool.query(
      `INSERT INTO user_profiles (id, profile_picture_url, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (id)
       DO UPDATE SET
         profile_picture_url = EXCLUDED.profile_picture_url,
         updated_at = NOW()
       RETURNING *`,
      [userId, blob.url]
    )

    return NextResponse.json({ url: blob.url, profile: result.rows[0] })
  } catch (error) {
    console.error('Error uploading profile picture:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
