import { render, screen } from '@testing-library/react'
import HomePage from '../app/page'

describe('Homepage', () => {
  it('renders the main hero section with key elements', () => {
    render(<HomePage />)

    // Check for main heading
    expect(screen.getByText('Your Cards,')).toBeInTheDocument()
    expect(screen.getByText('Automatically')).toBeInTheDocument()

    // Check for hero description
    expect(screen.getByText(/CardOnCue automatically displays your membership cards/)).toBeInTheDocument()

    // Check for call-to-action buttons
    expect(screen.getAllByText('Download on the App Store')).toHaveLength(3) // Header, footer, and homepage
    expect(screen.getByText('Android Version Coming Soon')).toBeInTheDocument()

    // Check for features section
    expect(screen.getByText('How CardOnCue Works')).toBeInTheDocument()

    // Check for feature items
    expect(screen.getByText('Location Detection')).toBeInTheDocument()
    expect(screen.getByText('Automatic Display')).toBeInTheDocument()
    expect(screen.getByText('Secure & Private')).toBeInTheDocument()

    // Check for benefits section
    expect(screen.getByText('Perfect For')).toBeInTheDocument()
    expect(screen.getByText('Costco & Warehouse Clubs')).toBeInTheDocument()
    expect(screen.getByText('Libraries & Bookstores')).toBeInTheDocument()

    // Check for final CTA
    expect(screen.getByText('Ready to Never Miss a Card Again?')).toBeInTheDocument()
  })

  it('matches the snapshot', () => {
    const { container } = render(<HomePage />)
    expect(container.firstChild).toMatchSnapshot()
  })
})
