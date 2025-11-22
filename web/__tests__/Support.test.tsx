import { render, screen } from '@testing-library/react'
import SupportPage from '../app/support/page'

describe('Support Page', () => {
  it('renders the support page with FAQ and help resources', () => {
    render(<SupportPage />)

    // Check for main heading
    expect(screen.getByRole('heading', { name: /Support & FAQ/ })).toBeInTheDocument()

    // Check for description
    expect(screen.getByText(/Find answers to common questions about CardOnCue/)).toBeInTheDocument()

    // Check for contact support button
    expect(screen.getAllByText('Contact Support')).toHaveLength(2) // Support page and header nav

    // Check for category filters
    expect(screen.getByText('All Questions')).toBeInTheDocument()
    expect(screen.getByText('Getting Started')).toBeInTheDocument()
    expect(screen.getByText('Location & Detection')).toBeInTheDocument()

    // Check for some FAQ questions
    expect(screen.getByText('What is CardOnCue?')).toBeInTheDocument()
    expect(screen.getByText('How does location detection work?')).toBeInTheDocument()
    expect(screen.getByText('How are my cards kept secure?')).toBeInTheDocument()

    // Check for help section
    expect(screen.getByText('Still Need Help?')).toBeInTheDocument()
    expect(screen.getByText('Email Us Directly')).toBeInTheDocument()
  })

  it('matches the snapshot', () => {
    const { container } = render(<SupportPage />)
    expect(container.firstChild).toMatchSnapshot()
  })
})
