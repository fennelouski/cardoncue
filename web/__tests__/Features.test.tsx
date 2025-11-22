import { render, screen } from '@testing-library/react'
import FeaturesPage from '../app/features/page'

describe('Features Page', () => {
  it('renders the features page with all feature sections', () => {
    render(<FeaturesPage />)

    // Check for main heading
    expect(screen.getByText('Powerful Features for')).toBeInTheDocument()
    expect(screen.getByText('Modern Life')).toBeInTheDocument()

    // Check for feature titles
    expect(screen.getByText('Location-Aware Card Surfacing')).toBeInTheDocument()
    expect(screen.getByText('Auto-Rendered Barcodes & QR Codes')).toBeInTheDocument()
    expect(screen.getByText('Multi-Card Support')).toBeInTheDocument()
    expect(screen.getByText('One-Time Use Return QR Codes')).toBeInTheDocument()
    expect(screen.getByText('Region-Based Notifications')).toBeInTheDocument()
    expect(screen.getByText('Privacy & Security First')).toBeInTheDocument()

    // Check for use cases section
    expect(screen.getByText('Perfect For Everyday Activities')).toBeInTheDocument()
    expect(screen.getByText('Grocery Shopping')).toBeInTheDocument()
    expect(screen.getByText('Library Visits')).toBeInTheDocument()
    expect(screen.getByText('Retail Returns')).toBeInTheDocument()
    expect(screen.getByText('Theme Parks & Entertainment')).toBeInTheDocument()

    // Check for Android section
    expect(screen.getByText('Android Support Coming Soon')).toBeInTheDocument()
    expect(screen.getByText('Request Android Version')).toBeInTheDocument()
  })

  it('matches the snapshot', () => {
    const { container } = render(<FeaturesPage />)
    expect(container.firstChild).toMatchSnapshot()
  })
})
