import { NextRequest, NextResponse } from 'next/server'

interface ContactMessage {
  name: string
  email: string
  message: string
  timestamp: string
  ip?: string
  userAgent?: string
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

    if (!message || typeof message !== 'string' || message.trim().length < 10) {
      return NextResponse.json(
        { error: 'Message is required and must be at least 10 characters long' },
        { status: 400 }
      )
    }

    // Create contact message object
    const contactMessage: ContactMessage = {
      name: name.trim(),
      email: email.trim().toLowerCase(),
      message: message.trim(),
      timestamp: new Date().toISOString(),
      ip: request.headers.get('x-forwarded-for') ||
          request.headers.get('x-real-ip') ||
          'unknown',
      userAgent: request.headers.get('user-agent') || 'unknown'
    }

    // In production, you would:
    // 1. Store in database/ticketing system
    // 2. Send email to support team
    // 3. Send confirmation email to user
    // 4. Create support ticket

    // For now, we'll just log it and return success
    console.log('Contact message received:', {
      ...contactMessage,
      // Don't log sensitive info in production
      ip: undefined,
      userAgent: undefined
    })

    // Here you could:
    // - Save to database
    // - Send to ticketing system (Zendesk, Intercom, etc.)
    // - Send email notification
    // - Send auto-reply to user

    return NextResponse.json({
      success: true,
      message: 'Message sent successfully. We\'ll get back to you within 24 hours.',
      messageId: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    })
  } catch (error) {
    console.error('Contact API error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
