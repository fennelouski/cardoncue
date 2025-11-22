import { NextRequest, NextResponse } from 'next/server'

interface AndroidRequest {
  name: string
  email: string
  message?: string
  timestamp: string
  ip?: string
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { name, email, message } = body

    // Validate required fields
    if (!name || typeof name !== 'string' || name.trim().length === 0) {
      return NextResponse.json(
        { error: 'Name is required and must be a non-empty string' },
        { status: 400 }
      )
    }

    if (!email || typeof email !== 'string' || !/\S+@\S+\.\S+/.test(email)) {
      return NextResponse.json(
        { error: 'Valid email is required' },
        { status: 400 }
      )
    }

    if (message && typeof message !== 'string') {
      return NextResponse.json(
        { error: 'Message must be a string' },
        { status: 400 }
      )
    }

    // Create request object
    const androidRequest: AndroidRequest = {
      name: name.trim(),
      email: email.trim().toLowerCase(),
      message: message?.trim(),
      timestamp: new Date().toISOString(),
      ip: request.headers.get('x-forwarded-for') ||
          request.headers.get('x-real-ip') ||
          'unknown'
    }

    // In production, you would:
    // 1. Store in database
    // 2. Send confirmation email
    // 3. Add to mailing list
    // 4. Send notification to team

    // For now, we'll just log it and return success
    console.log('Android request received:', {
      ...androidRequest,
      // Don't log IP in production for privacy
      ip: undefined
    })

    // Here you could:
    // - Save to Vercel KV
    // - Send to database
    // - Add to email marketing service
    // - Send confirmation email

    return NextResponse.json({
      success: true,
      message: 'Android request submitted successfully',
      requestId: `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    })
  } catch (error) {
    console.error('Android request API error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
