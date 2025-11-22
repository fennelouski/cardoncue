import { render, screen } from '@testing-library/react'
import { Footer } from '../app/components/Footer'

describe('Footer', () => {
  it('renders the footer with navigation, branding, and social links', () => {
    render(<Footer />)

    // Check for the main branding
    expect(screen.getByText('CardOnCue')).toBeInTheDocument()

    // Check for navigation links
    expect(screen.getByText('Home')).toBeInTheDocument()
    expect(screen.getByText('Features')).toBeInTheDocument()
    expect(screen.getByText('Support')).toBeInTheDocument()
    expect(screen.getByText('Contact')).toBeInTheDocument()

    // Check for legal links
    expect(screen.getByText('Privacy Policy')).toBeInTheDocument()
    expect(screen.getByText('Terms of Use')).toBeInTheDocument()

    // Check for app store links
    expect(screen.getByText('Download on the App Store')).toBeInTheDocument()
    expect(screen.getByText('Android Version Coming Soon →')).toBeInTheDocument()

    // Check for copyright
    expect(screen.getByText(/© 2024 CardOnCue/)).toBeInTheDocument()

    // Check for social icons
    expect(screen.getByTestId('github-icon')).toBeInTheDocument()
    expect(screen.getByTestId('twitter-icon')).toBeInTheDocument()
    expect(screen.getByTestId('mail-icon')).toBeInTheDocument()
  })

  it('matches the snapshot', () => {
    const { container } = render(<Footer />)
    expect(container.firstChild).toMatchSnapshot()
  })
})
