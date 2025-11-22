import { render, screen } from '@testing-library/react'
import AndroidPage from '../app/android/page'

describe('Android Page', () => {
  it('renders the Android request page with form and information', () => {
    render(<AndroidPage />)

    // Check for main heading
    expect(screen.getByRole('heading', { name: /Android Version Coming Soon/ })).toBeInTheDocument()

    // Check for description
    expect(screen.getByText(/We're working hard to bring CardOnCue to Android devices/)).toBeInTheDocument()

    // Check for form elements
    expect(screen.getByLabelText('Name *')).toBeInTheDocument()
    expect(screen.getByLabelText('Email *')).toBeInTheDocument()
    expect(screen.getByLabelText('Message (Optional)')).toBeInTheDocument()

    // Check for submit button
    expect(screen.getByRole('button', { name: 'Request Android Access' })).toBeInTheDocument()

    // Check for benefits section
    expect(screen.getByText('Why Android Support Matters')).toBeInTheDocument()
    expect(screen.getByText('Universal Access')).toBeInTheDocument()
    expect(screen.getByText('Cross-Platform')).toBeInTheDocument()
    expect(screen.getByText('Complete Solution')).toBeInTheDocument()

    // Check for privacy notice
    expect(screen.getByText(/We respect your privacy and will only use your information/)).toBeInTheDocument()
  })

  it('matches the snapshot', () => {
    const { container } = render(<AndroidPage />)
    expect(container.firstChild).toMatchSnapshot()
  })
})
