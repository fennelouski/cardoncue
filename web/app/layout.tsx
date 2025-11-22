import type { Metadata } from 'next'
import { ClerkProvider } from '@clerk/nextjs'
import { Inter } from 'next/font/google'
import './styles/globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'CardOnCue - Location-Aware Digital Cards',
  description: 'Automatically show your membership cards, library cards, and barcodes when you enter relevant locations. Available on iOS with Android coming soon.',
  keywords: 'digital cards, membership cards, library cards, barcode, QR code, location-aware, iOS app',
  authors: [{ name: 'CardOnCue Team' }],
  openGraph: {
    title: 'CardOnCue - Location-Aware Digital Cards',
    description: 'Automatically show your membership cards, library cards, and barcodes when you enter relevant locations.',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'CardOnCue - Location-Aware Digital Cards',
    description: 'Automatically show your membership cards, library cards, and barcodes when you enter relevant locations.',
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <ClerkProvider>
      <html lang="en" className="dark">
        <body className={inter.className}>
          {children}
        </body>
      </html>
    </ClerkProvider>
  )
}
