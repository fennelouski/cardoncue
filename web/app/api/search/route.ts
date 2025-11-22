import { NextRequest, NextResponse } from 'next/server'

interface SearchResult {
  id: string
  name: string
  type: 'retail' | 'library' | 'entertainment' | 'grocery'
  address?: string
  city?: string
  state?: string
  supported: boolean
  logo?: string
}

// Sample data - in production this would come from a database
const sampleLocations: SearchResult[] = [
  {
    id: '1',
    name: 'Costco Wholesale',
    type: 'grocery',
    city: 'San Francisco',
    state: 'CA',
    supported: true
  },
  {
    id: '2',
    name: 'Whole Foods Market',
    type: 'grocery',
    city: 'San Francisco',
    state: 'CA',
    supported: true
  },
  {
    id: '3',
    name: 'San Francisco Public Library',
    type: 'library',
    city: 'San Francisco',
    state: 'CA',
    supported: true
  },
  {
    id: '4',
    name: 'Kohl\'s',
    type: 'retail',
    city: 'San Francisco',
    state: 'CA',
    supported: true
  },
  {
    id: '5',
    name: 'Best Buy',
    type: 'retail',
    city: 'San Francisco',
    state: 'CA',
    supported: false
  },
  {
    id: '6',
    name: 'Disney World',
    type: 'entertainment',
    city: 'Orlando',
    state: 'FL',
    supported: true
  },
  {
    id: '7',
    name: 'Universal Studios',
    type: 'entertainment',
    city: 'Orlando',
    state: 'FL',
    supported: true
  },
  {
    id: '8',
    name: 'Trader Joe\'s',
    type: 'grocery',
    city: 'San Francisco',
    state: 'CA',
    supported: true
  },
  {
    id: '9',
    name: 'Barnes & Noble',
    type: 'retail',
    city: 'San Francisco',
    state: 'CA',
    supported: false
  },
  {
    id: '10',
    name: 'Six Flags',
    type: 'entertainment',
    city: 'Various',
    state: 'CA',
    supported: true
  },
  {
    id: '11',
    name: 'Walmart',
    type: 'retail',
    city: 'Various',
    state: 'US',
    supported: false
  },
  {
    id: '12',
    name: 'Target',
    type: 'retail',
    city: 'Various',
    state: 'US',
    supported: false
  },
  {
    id: '13',
    name: 'Starbucks',
    type: 'retail',
    city: 'Various',
    state: 'US',
    supported: false
  },
  {
    id: '14',
    name: 'McDonald\'s',
    type: 'retail',
    city: 'Various',
    state: 'US',
    supported: false
  },
  {
    id: '15',
    name: 'Home Depot',
    type: 'retail',
    city: 'Various',
    state: 'US',
    supported: false
  }
]

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const query = searchParams.get('query')?.toLowerCase().trim()

    if (!query || query.length < 2) {
      return NextResponse.json({
        results: [],
        message: 'Query must be at least 2 characters long'
      })
    }

    // Filter results based on query
    const results = sampleLocations.filter(location =>
      location.name.toLowerCase().includes(query) ||
      location.city?.toLowerCase().includes(query) ||
      location.state?.toLowerCase().includes(query) ||
      location.type.toLowerCase().includes(query)
    )

    // Sort by relevance (name matches first, then supported locations)
    results.sort((a, b) => {
      const aNameMatch = a.name.toLowerCase().includes(query) ? 1 : 0
      const bNameMatch = b.name.toLowerCase().includes(query) ? 1 : 0

      if (aNameMatch !== bNameMatch) {
        return bNameMatch - aNameMatch
      }

      // Then sort by supported status
      return Number(b.supported) - Number(a.supported)
    })

    return NextResponse.json({
      results,
      total: results.length,
      query
    })
  } catch (error) {
    console.error('Search API error:', error)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
