import { render, screen } from '@testing-library/react'
import SearchPage from '../app/search/page'

describe('Search Page', () => {
  it('renders the search page with search functionality', () => {
    render(<SearchPage />)

    // Check for main heading
    expect(screen.getByRole('heading', { name: /Find CardOnCue Locations/ })).toBeInTheDocument()

    // Check for description
    expect(screen.getByText(/Search for businesses, libraries, and locations/)).toBeInTheDocument()

    // Check for search input
    expect(screen.getByPlaceholderText('Search for Costco, libraries, theme parks...')).toBeInTheDocument()

    // Check for search icon
    expect(screen.getAllByTestId('search-icon')).toHaveLength(2) // Header nav and search page

    // Check for popular searches
    expect(screen.getByText('Popular searches:')).toBeInTheDocument()
    expect(screen.getByText('Costco')).toBeInTheDocument()
    expect(screen.getByText('libraries')).toBeInTheDocument()
    expect(screen.getByText('theme parks')).toBeInTheDocument()

    // Check for no results state
    expect(screen.getByText('Start searching')).toBeInTheDocument()
  })

  it('matches the snapshot', () => {
    const { container } = render(<SearchPage />)
    expect(container.firstChild).toMatchSnapshot()
  })
})
