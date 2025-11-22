import { render, screen } from '@testing-library/react'
import { Header } from '../app/components/Header'

describe('Header', () => {
  it('renders the header with navigation and branding', () => {
    render(<Header />)

    // Check for the main branding
    expect(screen.getByText('CardOnCue')).toBeInTheDocument()

    // Check for navigation links
    expect(screen.getByText('Home')).toBeInTheDocument()
    expect(screen.getByText('Features')).toBeInTheDocument()
    expect(screen.getByText('Search')).toBeInTheDocument()
    expect(screen.getByText('Support')).toBeInTheDocument()
    expect(screen.getByText('Contact')).toBeInTheDocument()

    // Check for authentication elements
    expect(screen.getByText('Sign In')).toBeInTheDocument()
    expect(screen.getByTestId('user-button')).toBeInTheDocument()

    // Check for mobile menu button
    expect(screen.getByTestId('menu-icon')).toBeInTheDocument()
  })

  it('matches the snapshot', () => {
    const { container } = render(<Header />)
    expect(container.firstChild).toMatchSnapshot()
  })
})
