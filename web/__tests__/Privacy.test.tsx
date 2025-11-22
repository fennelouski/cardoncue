import { render, screen } from '@testing-library/react'
import PrivacyPage from '../app/privacy/page'

describe('Privacy Page', () => {
  it('renders the privacy policy page with legal content', () => {
    render(<PrivacyPage />)

    // Check for main heading
    expect(screen.getByRole('heading', { name: 'Privacy Policy' })).toBeInTheDocument()

    // Check for last updated
    expect(screen.getByText(/Last updated:/)).toBeInTheDocument()

    // Check for main sections
    expect(screen.getByText('1. Introduction')).toBeInTheDocument()
    expect(screen.getByText('2. Information We Collect')).toBeInTheDocument()
    expect(screen.getByText('3. How We Use Your Information')).toBeInTheDocument()
    expect(screen.getByText('4. Data Security and Encryption')).toBeInTheDocument()
    expect(screen.getByText('5. Location Data Handling')).toBeInTheDocument()
    expect(screen.getByText('6. Information Sharing and Disclosure')).toBeInTheDocument()
    expect(screen.getByText('7. Data Retention')).toBeInTheDocument()
    expect(screen.getByText('8. Your Rights and Choices')).toBeInTheDocument()
    expect(screen.getByText('9. Cookies and Tracking')).toBeInTheDocument()
    expect(screen.getByText('10. International Data Transfers')).toBeInTheDocument()
    expect(screen.getByText('11. Children\'s Privacy')).toBeInTheDocument()
    expect(screen.getByText('12. Changes to This Policy')).toBeInTheDocument()
    expect(screen.getByText('13. Contact Us')).toBeInTheDocument()

    // Check for data controller note
    expect(screen.getByText(/Data Controller:/)).toBeInTheDocument()
  })

  it('matches the snapshot', () => {
    const { container } = render(<PrivacyPage />)
    expect(container.firstChild).toMatchSnapshot()
  })
})
