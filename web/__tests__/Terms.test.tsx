import { render, screen } from '@testing-library/react'
import TermsPage from '../app/terms/page'

describe('Terms Page', () => {
  it('renders the terms of use page with legal content', () => {
    render(<TermsPage />)

    // Check for main heading
    expect(screen.getByRole('heading', { name: /Terms of Use/ })).toBeInTheDocument()

    // Check for last updated
    expect(screen.getByText(/Last updated:/)).toBeInTheDocument()

    // Check for main sections
    expect(screen.getByText('1. Acceptance of Terms')).toBeInTheDocument()
    expect(screen.getByText('2. Description of Service')).toBeInTheDocument()
    expect(screen.getByText('3. User Accounts')).toBeInTheDocument()
    expect(screen.getByText('4. Privacy and Data Security')).toBeInTheDocument()
    expect(screen.getByText('5. Acceptable Use')).toBeInTheDocument()
    expect(screen.getByText('6. Subscription and Billing')).toBeInTheDocument()
    expect(screen.getByText('7. Termination')).toBeInTheDocument()
    expect(screen.getByText('8. Disclaimers')).toBeInTheDocument()
    expect(screen.getByText('9. Limitation of Liability')).toBeInTheDocument()
    expect(screen.getByText('10. Changes to Terms')).toBeInTheDocument()
    expect(screen.getByText('11. Contact Information')).toBeInTheDocument()
  })

  it('matches the snapshot', () => {
    const { container } = render(<TermsPage />)
    expect(container.firstChild).toMatchSnapshot()
  })
})
