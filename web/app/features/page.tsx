'use client'

import { motion } from 'framer-motion'
import { Header } from '../components/Header'
import { Footer } from '../components/Footer'
import {
  MapPin,
  Smartphone,
  Shield,
  Users,
  QrCode,
  Clock,
  Bell,
  ArrowRightLeft
} from 'lucide-react'
import Link from 'next/link'

export default function FeaturesPage() {
  const features = [
    {
      icon: MapPin,
      title: 'Location-Aware Card Surfacing',
      description: 'Your iPhone detects when you enter stores, libraries, and other locations. Relevant cards automatically appear on your lock screen or in the CardOnCue app.',
      details: [
        'Precise location detection using GPS and Wi-Fi',
        'Customizable notification radius (50-500 meters)',
        'Works in background without draining battery',
        'Region-based grouping for efficient monitoring'
      ]
    },
    {
      icon: QrCode,
      title: 'Auto-Rendered Barcodes & QR Codes',
      description: 'Cards display with perfectly rendered barcodes and QR codes that scan instantly at checkout counters and self-service kiosks.',
      details: [
        'Support for all major barcode formats (Code 128, QR, EAN-13, etc.)',
        'High-resolution rendering for reliable scanning',
        'Secure one-time use options for returns',
        'Real-time barcode generation'
      ]
    },
    {
      icon: Users,
      title: 'Multi-Card Support',
      description: 'Manage cards for your entire family - kids\' library cards, multiple memberships, and shared household accounts.',
      details: [
        'Unlimited cards per account',
        'Family sharing capabilities',
        'Card grouping and organization',
        'Quick card switching'
      ]
    },
    {
      icon: ArrowRightLeft,
      title: 'One-Time Use Return QR Codes',
      description: 'Generate temporary QR codes for retail returns at stores like Amazon at Kohl\'s, ensuring security while maintaining convenience.',
      details: [
        'Secure, expiring QR codes',
        'Return-specific formatting',
        'Audit trail for security',
        'Integration with major retailers'
      ]
    },
    {
      icon: Bell,
      title: 'Region-Based Notifications',
      description: 'Get notified when entering theme parks, Costco, Whole Foods, libraries, and other supported locations.',
      details: [
        'Smart notification scheduling',
        'Location history tracking',
        'Customizable alert preferences',
        'Quiet hours support'
      ]
    },
    {
      icon: Shield,
      title: 'Privacy & Security First',
      description: 'Your card data is end-to-end encrypted and never stored in plain text. Cards are only displayed when you need them.',
      details: [
        'AES-256-GCM encryption',
        'Zero-knowledge architecture',
        'Secure element integration',
        'Privacy-preserving location data'
      ]
    }
  ]

  const useCases = [
    {
      title: 'Grocery Shopping',
      locations: ['Costco', 'Whole Foods', 'Trader Joe\'s', 'Kroger'],
      description: 'Membership cards appear automatically when you arrive at warehouse clubs and grocery stores.'
    },
    {
      title: 'Library Visits',
      locations: ['Public Libraries', 'University Libraries', 'School Libraries'],
      description: 'Borrow books seamlessly with library cards that appear when you enter library premises.'
    },
    {
      title: 'Retail Returns',
      locations: ['Amazon at Kohl\'s', 'Best Buy', 'Target', 'Walmart'],
      description: 'Generate secure return QR codes for hassle-free returns at participating retailers.'
    },
    {
      title: 'Theme Parks & Entertainment',
      locations: ['Disney Parks', 'Universal Studios', 'Six Flags', 'Local Amusement Parks'],
      description: 'Season passes and tickets display automatically at park entrances and attractions.'
    }
  ]

  return (
    <div className="min-h-screen flex flex-col">
      <Header />

      <main className="flex-grow">
        {/* Hero Section */}
        <section className="bg-gradient-to-br from-primary-50 to-primary-100 dark:from-gray-900 dark:to-gray-800 py-20">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              className="text-center"
            >
              <h1 className="text-4xl md:text-6xl font-bold text-gray-900 dark:text-white mb-6">
                Powerful Features for <span className="text-primary-600">Modern Life</span>
              </h1>
              <p className="text-xl text-gray-600 dark:text-gray-300 mb-8 max-w-3xl mx-auto">
                Discover how CardOnCue transforms the way you interact with digital cards,
                making everyday activities seamless and secure.
              </p>
            </motion.div>
          </div>
        </section>

        {/* Features Grid */}
        <section className="py-20 bg-white dark:bg-gray-900">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="grid lg:grid-cols-2 gap-12">
              {features.map((feature, index) => (
                <motion.div
                  key={feature.title}
                  initial={{ opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.6, delay: index * 0.1 }}
                  viewport={{ once: true }}
                  className="card"
                >
                  <div className="flex items-start space-x-4">
                    <div className="flex-shrink-0">
                      <div className="w-12 h-12 bg-primary-100 dark:bg-primary-900 rounded-lg flex items-center justify-center">
                        <feature.icon className="w-6 h-6 text-primary-600" />
                      </div>
                    </div>
                    <div className="flex-grow">
                      <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-3">
                        {feature.title}
                      </h3>
                      <p className="text-gray-600 dark:text-gray-300 mb-4">
                        {feature.description}
                      </p>
                      <ul className="space-y-2">
                        {feature.details.map((detail, detailIndex) => (
                          <li key={detailIndex} className="flex items-start space-x-2">
                            <div className="w-1.5 h-1.5 bg-primary-600 rounded-full mt-2 flex-shrink-0"></div>
                            <span className="text-sm text-gray-600 dark:text-gray-300">{detail}</span>
                          </li>
                        ))}
                      </ul>
                    </div>
                  </div>
                </motion.div>
              ))}
            </div>
          </div>
        </section>

        {/* Use Cases */}
        <section className="py-20 bg-gray-50 dark:bg-gray-800">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <motion.div
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              transition={{ duration: 0.6 }}
              viewport={{ once: true }}
              className="text-center mb-16"
            >
              <h2 className="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white mb-4">
                Perfect For Everyday Activities
              </h2>
              <p className="text-lg text-gray-600 dark:text-gray-300 max-w-2xl mx-auto">
                CardOnCue works seamlessly across a wide range of locations and use cases
              </p>
            </motion.div>

            <div className="grid md:grid-cols-2 gap-8">
              {useCases.map((useCase, index) => (
                <motion.div
                  key={useCase.title}
                  initial={{ opacity: 0, y: 20 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.6, delay: index * 0.1 }}
                  viewport={{ once: true }}
                  className="card"
                >
                  <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-3">
                    {useCase.title}
                  </h3>
                  <div className="flex flex-wrap gap-2 mb-4">
                    {useCase.locations.map((location) => (
                      <span
                        key={location}
                        className="px-3 py-1 bg-primary-100 dark:bg-primary-900 text-primary-700 dark:text-primary-300 text-sm rounded-full"
                      >
                        {location}
                      </span>
                    ))}
                  </div>
                  <p className="text-gray-600 dark:text-gray-300">
                    {useCase.description}
                  </p>
                </motion.div>
              ))}
            </div>
          </div>
        </section>

        {/* Future Android Support */}
        <section className="py-20 bg-primary-600">
          <div className="max-w-4xl mx-auto text-center px-4 sm:px-6 lg:px-8">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              viewport={{ once: true }}
            >
              <h2 className="text-3xl md:text-4xl font-bold text-white mb-4">
                Android Support Coming Soon
              </h2>
              <p className="text-xl text-primary-100 mb-8">
                We're working hard to bring CardOnCue to Android devices.
                Join our waitlist to be among the first to know when it's available.
              </p>

              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <Link
                  href="/android"
                  className="bg-white text-primary-600 hover:bg-gray-50 font-semibold py-4 px-8 rounded-lg transition-colors duration-200"
                >
                  Request Android Version
                </Link>
                <a
                  href="#"
                  className="border-2 border-white text-white hover:bg-white hover:text-primary-600 font-semibold py-4 px-8 rounded-lg transition-colors duration-200"
                >
                  Download iOS Version
                </a>
              </div>
            </motion.div>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  )
}
