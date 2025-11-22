'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { Header } from '../components/Header'
import { Footer } from '../components/Footer'
import { Search, MapPin, Building } from 'lucide-react'

interface SearchResult {
  id: string
  name: string
  type: 'retail' | 'library' | 'entertainment' | 'grocery'
  address?: string
  city?: string
  state?: string
  supported: boolean
}

export default function SearchPage() {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<SearchResult[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState('')

  // Sample data for demonstration - in production this would come from the API
  const sampleData: SearchResult[] = [
    { id: '1', name: 'Costco Wholesale', type: 'grocery', city: 'San Francisco', state: 'CA', supported: true },
    { id: '2', name: 'Whole Foods Market', type: 'grocery', city: 'San Francisco', state: 'CA', supported: true },
    { id: '3', name: 'San Francisco Public Library', type: 'library', city: 'San Francisco', state: 'CA', supported: true },
    { id: '4', name: 'Kohl\'s', type: 'retail', city: 'San Francisco', state: 'CA', supported: true },
    { id: '5', name: 'Best Buy', type: 'retail', city: 'San Francisco', state: 'CA', supported: false },
    { id: '6', name: 'Disney World', type: 'entertainment', city: 'Orlando', state: 'FL', supported: true },
    { id: '7', name: 'Universal Studios', type: 'entertainment', city: 'Orlando', state: 'FL', supported: true },
    { id: '8', name: 'Trader Joe\'s', type: 'grocery', city: 'San Francisco', state: 'CA', supported: true },
    { id: '9', name: 'Barnes & Noble', type: 'retail', city: 'San Francisco', state: 'CA', supported: false },
    { id: '10', name: 'Six Flags', type: 'entertainment', city: 'Various', state: 'CA', supported: true },
  ]

  useEffect(() => {
    const searchLocations = async () => {
      if (query.length < 2) {
        setResults([])
        return
      }

      setIsLoading(true)
      setError('')

      try {
        // In production, this would be a real API call
        // const response = await fetch(`/api/search?query=${encodeURIComponent(query)}`)
        // const data = await response.json()

        // For now, simulate API call with local filtering
        await new Promise(resolve => setTimeout(resolve, 300)) // Simulate network delay

        const filteredResults = sampleData.filter(item =>
          item.name.toLowerCase().includes(query.toLowerCase()) ||
          item.city?.toLowerCase().includes(query.toLowerCase()) ||
          item.type.toLowerCase().includes(query.toLowerCase())
        )

        setResults(filteredResults)
      } catch (err) {
        setError('Failed to search locations. Please try again.')
        setResults([])
      } finally {
        setIsLoading(false)
      }
    }

    const debounceTimer = setTimeout(searchLocations, 300)
    return () => clearTimeout(debounceTimer)
  }, [query])

  const getTypeIcon = (type: SearchResult['type']) => {
    switch (type) {
      case 'grocery':
        return '🛒'
      case 'library':
        return '📚'
      case 'retail':
        return '🛍️'
      case 'entertainment':
        return '🎢'
      default:
        return '🏢'
    }
  }

  const getTypeColor = (type: SearchResult['type']) => {
    switch (type) {
      case 'grocery':
        return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300'
      case 'library':
        return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300'
      case 'retail':
        return 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-300'
      case 'entertainment':
        return 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-300'
      default:
        return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300'
    }
  }

  return (
    <div className="min-h-screen flex flex-col">
      <Header />

      <main className="flex-grow">
        {/* Hero Section */}
        <section className="bg-gradient-to-br from-primary-50 to-primary-100 dark:from-gray-900 dark:to-gray-800 py-20">
          <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
            >
              <h1 className="text-4xl md:text-5xl font-bold text-gray-900 dark:text-white mb-6">
                Find CardOnCue <span className="text-primary-600">Locations</span>
              </h1>
              <p className="text-xl text-gray-600 dark:text-gray-300 mb-8">
                Search for businesses, libraries, and locations where CardOnCue works.
                See what's supported in your area.
              </p>

              {/* Search Input */}
              <div className="max-w-2xl mx-auto relative">
                <div className="relative">
                  <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
                  <input
                    type="text"
                    placeholder="Search for Costco, libraries, theme parks..."
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    className="input-field pl-12 pr-4 py-4 text-lg w-full"
                  />
                </div>
              </div>
            </motion.div>
          </div>
        </section>

        {/* Results Section */}
        <section className="py-12 bg-white dark:bg-gray-900">
          <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
            {isLoading && (
              <div className="text-center py-12">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600 mx-auto"></div>
                <p className="text-gray-600 dark:text-gray-300 mt-4">Searching locations...</p>
              </div>
            )}

            {error && (
              <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4 mb-8">
                <p className="text-red-800 dark:text-red-200">{error}</p>
              </div>
            )}

            {results.length > 0 && (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.3 }}
              >
                <div className="mb-6">
                  <p className="text-gray-600 dark:text-gray-300">
                    Found {results.length} location{results.length !== 1 ? 's' : ''}
                  </p>
                </div>

                <div className="space-y-4">
                  {results.map((result) => (
                    <motion.div
                      key={result.id}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="card hover:shadow-md transition-shadow duration-200"
                    >
                      <div className="flex items-start space-x-4">
                        <div className="text-2xl">{getTypeIcon(result.type)}</div>
                        <div className="flex-grow">
                          <div className="flex items-start justify-between">
                            <div>
                              <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
                                {result.name}
                              </h3>
                              <div className="flex items-center space-x-2 mt-1">
                                <MapPin className="w-4 h-4 text-gray-400" />
                                <span className="text-sm text-gray-600 dark:text-gray-300">
                                  {result.city}, {result.state}
                                </span>
                              </div>
                            </div>
                            <div className="flex items-center space-x-2">
                              <span className={`px-2 py-1 text-xs font-medium rounded-full ${getTypeColor(result.type)}`}>
                                {result.type.charAt(0).toUpperCase() + result.type.slice(1)}
                              </span>
                              {result.supported ? (
                                <span className="px-2 py-1 text-xs font-medium rounded-full bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300">
                                  Supported
                                </span>
                              ) : (
                                <span className="px-2 py-1 text-xs font-medium rounded-full bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300">
                                  Coming Soon
                                </span>
                              )}
                            </div>
                          </div>
                        </div>
                      </div>
                    </motion.div>
                  ))}
                </div>
              </motion.div>
            )}

            {query.length >= 2 && results.length === 0 && !isLoading && (
              <div className="text-center py-12">
                <Building className="w-16 h-16 text-gray-300 dark:text-gray-600 mx-auto mb-4" />
                <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-2">
                  No locations found
                </h3>
                <p className="text-gray-600 dark:text-gray-300">
                  We couldn't find any locations matching "{query}". Try searching for "Costco", "libraries", or "theme parks".
                </p>
              </div>
            )}

            {query.length < 2 && (
              <div className="text-center py-12">
                <Search className="w-16 h-16 text-gray-300 dark:text-gray-600 mx-auto mb-4" />
                <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-2">
                  Start searching
                </h3>
                <p className="text-gray-600 dark:text-gray-300">
                  Enter at least 2 characters to search for CardOnCue-supported locations.
                </p>

                {/* Popular Searches */}
                <div className="mt-8">
                  <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">Popular searches:</p>
                  <div className="flex flex-wrap justify-center gap-2">
                    {['Costco', 'libraries', 'Whole Foods', 'theme parks', 'Kohl\'s'].map((term) => (
                      <button
                        key={term}
                        onClick={() => setQuery(term)}
                        className="px-4 py-2 bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 rounded-full text-sm hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors duration-200"
                      >
                        {term}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </div>
        </section>
      </main>

      <Footer />
    </div>
  )
}
