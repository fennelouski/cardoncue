import { render, screen } from '@testing-library/react'
import ContactPage from '../app/contact/page'

describe('Contact Page', () => {
  it('renders the contact page with form and contact information', () => {
    render(<ContactPage />)

    // Check for main heading
    expect(screen.getByRole('heading', { name: /Get in Touch/ })).toBeInTheDocument()

    // Check for description
    expect(screen.getByText(/Have questions about CardOnCue?/)).toBeInTheDocument()

    // Check for form elements
    expect(screen.getByLabelText('Name *')).toBeInTheDocument()
    expect(screen.getByLabelText('Email *')).toBeInTheDocument()
    expect(screen.getByLabelText('Message *')).toBeInTheDocument()

    // Check for submit button
    expect(screen.getByRole('button', { name: 'Send Message' })).toBeInTheDocument()

    // Check for contact information
    expect(screen.getByText('Response Time')).toBeInTheDocument()
    expect(screen.getByText('Other Ways to Reach Us')).toBeInTheDocument()
    expect(screen.getByText('Quick Links')).toBeInTheDocument()

    // Check for quick links
    expect(screen.getByText('Support & FAQ →')).toBeInTheDocument()
    expect(screen.getByText('Features Overview →')).toBeInTheDocument()
    expect(screen.getByText('Find Locations →')).toBeInTheDocument()
  })

  it('matches the snapshot', () => {
    const { container } = render(<ContactPage />)
    expect(container.firstChild).toMatchSnapshot()
  })
})
