import { render, screen } from '@testing-library/react'
import TermsPage from '../app/terms/page'

describe('Terms Page', () => {
  it('renders the terms of service page with legal content', () => {
    render(<TermsPage />)

    // Check for main heading
    expect(screen.getByRole('heading', { name: /Terms of Service/ })).toBeInTheDocument()

    // Check for last updated
    expect(screen.getByText(/Last updated:/)).toBeInTheDocument()
    expect(screen.getByText('Effective Date and Version History')).toBeInTheDocument()
    expect(screen.getByText(/Effective date:/)).toBeInTheDocument()

    // Check for critical sections
    expect(screen.getByText('1. Acceptance of Terms')).toBeInTheDocument()
    expect(screen.getByText('3. Description of the Service')).toBeInTheDocument()
    expect(screen.getByText('6. Geolocation and Notifications')).toBeInTheDocument()
    expect(screen.getByText('8. AI-Assisted Features')).toBeInTheDocument()
    expect(screen.getByText('15. Disclaimers')).toBeInTheDocument()
    expect(screen.getByText('16. Limitation of Liability')).toBeInTheDocument()
    expect(screen.getByText('20. Binding Arbitration and Class Action Waiver')).toBeInTheDocument()
    expect(screen.getByText('24. Contact Information')).toBeInTheDocument()
  })

  it('matches the snapshot', () => {
    const { container } = render(<TermsPage />)
    expect(container.firstChild).toMatchSnapshot()
  })
})
