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
    expect(screen.getByText('5. Data Security')).toBeInTheDocument()
    expect(screen.getByText('6. Location Data Handling')).toBeInTheDocument()
    expect(screen.getByText('7. How We Share Information')).toBeInTheDocument()
    expect(screen.getByText('10. Cookies and Similar Technologies')).toBeInTheDocument()
    expect(screen.getByText('12. Children\'s Privacy')).toBeInTheDocument()
    expect(screen.getByText('15. Contact Us')).toBeInTheDocument()

    // Check for data controller note
    expect(screen.getByText(/Data Controller:/)).toBeInTheDocument()
    expect(screen.getAllByText('Terms of Service').length).toBeGreaterThanOrEqual(2)
  })

  it('matches the snapshot', () => {
    const { container } = render(<PrivacyPage />)
    expect(container.firstChild).toMatchSnapshot()
  })
})
