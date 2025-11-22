'use client'

import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { Header } from '../components/Header'
import { Footer } from '../components/Footer'
import { ChevronDown, HelpCircle, MapPin, CreditCard, Bell, Shield, Smartphone } from 'lucide-react'

interface FAQ {
  id: string
  question: string
  answer: string
  category: 'getting-started' | 'location' | 'cards' | 'security' | 'billing' | 'technical'
}

const faqs: FAQ[] = [
  {
    id: 'what-is-cardoncue',
    question: 'What is CardOnCue?',
    answer: 'CardOnCue is a location-aware digital card storage app that automatically displays your membership cards, library cards, and barcodes when you enter relevant locations. Instead of fumbling for physical cards or remembering which card to use where, CardOnCue handles it for you.',
    category: 'getting-started'
  },
  {
    id: 'how-location-works',
    question: 'How does location detection work?',
    answer: 'CardOnCue uses your iPhone\'s GPS and Wi-Fi positioning to detect when you enter locations like Costco, libraries, or theme parks. The app requests precise location permission to provide accurate detection within 50-500 meters of supported locations. Your location data is processed locally on your device and is never stored or shared.',
    category: 'location'
  },
  {
    id: 'why-precise-location',
    question: 'Why does CardOnCue need precise location permission?',
    answer: 'Precise location permission allows CardOnCue to accurately detect when you enter specific stores, libraries, or venues. This ensures your cards appear at the right time and place. The app only uses location data locally on your device - it\'s never sent to our servers or shared with third parties.',
    category: 'location'
  },
  {
    id: 'how-cards-secure',
    question: 'How are my cards kept secure?',
    answer: 'Your card data is encrypted end-to-end using AES-256-GCM encryption. The encryption keys are stored securely on your device, and we never have access to your actual card information. Cards are only displayed when you\'re in the relevant location, and you can remove cards at any time.',
    category: 'security'
  },
  {
    id: 'add-cards',
    question: 'How do I add cards to CardOnCue?',
    answer: 'Currently, cards are added through our iOS app. You can scan barcodes, manually enter card details, or import from photos. We\'re working on web-based card management for easy setup. Each card is encrypted before storage.',
    category: 'cards'
  },
  {
    id: 'supported-locations',
    question: 'What locations are supported?',
    answer: 'CardOnCue currently supports major retailers like Costco, Whole Foods, and Kohl\'s, public libraries, theme parks like Disney and Universal, and many other locations. Use our search page to find supported locations in your area. We\'re constantly adding new locations based on user requests.',
    category: 'location'
  },
  {
    id: 'one-time-qr',
    question: 'How do one-time QR codes work?',
    answer: 'For returns at stores like Amazon at Kohl\'s, CardOnCue generates temporary, secure QR codes that expire after use. This provides the convenience of digital returns while maintaining security. Each QR code can only be used once and is cryptographically secure.',
    category: 'cards'
  },
  {
    id: 'notifications',
    question: 'Can I control notifications?',
    answer: 'Yes! You can customize notification preferences in the app settings. Choose which types of locations trigger notifications, set quiet hours, and adjust the detection radius. You can also disable notifications entirely if preferred.',
    category: 'technical'
  },
  {
    id: 'billing-works',
    question: 'How does billing and subscriptions work?',
    answer: 'CardOnCue uses a freemium model. Basic features are free, while premium features like unlimited cards and advanced location monitoring require a subscription. Billing is handled securely through our payment processor, and you can manage your subscription through the account dashboard.',
    category: 'billing'
  },
  {
    id: 'cancel-subscription',
    question: 'How do I cancel my subscription?',
    answer: 'You can manage or cancel your subscription anytime through your account dashboard. Go to Account → Subscriptions → Manage Billing. Cancellations take effect at the end of your current billing period, and you\'ll retain access to premium features until then.',
    category: 'billing'
  },
  {
    id: 'battery-impact',
    question: 'Does CardOnCue drain my battery?',
    answer: 'CardOnCue is designed to be battery-efficient. It uses region monitoring (geofencing) which is very power-efficient compared to constant GPS tracking. Most users see minimal to no impact on battery life.',
    category: 'technical'
  },
  {
    id: 'multiple-devices',
    question: 'Can I use CardOnCue on multiple devices?',
    answer: 'Currently, CardOnCue is iOS-only. You can have the app on multiple iOS devices, but cards need to be set up on each device individually. We\'re working on cross-device syncing and Android support.',
    category: 'technical'
  },
  {
    id: 'data-privacy',
    question: 'What data do you collect and how is it used?',
    answer: 'We collect minimal data necessary to provide our service: encrypted card data (which we cannot decrypt) and anonymous usage statistics to improve the app. Location data is processed locally on your device and never stored on our servers. We never sell or share your personal information.',
    category: 'security'
  },
  {
    id: 'android-timeline',
    question: 'When will Android version be available?',
    answer: 'We\'re actively developing the Android version and expect to launch in the coming months. Join our Android waitlist to be notified when it\'s ready. The Android version will have feature parity with iOS.',
    category: 'technical'
  }
]

const categories = [
  { id: 'getting-started', name: 'Getting Started', icon: HelpCircle },
  { id: 'location', name: 'Location & Detection', icon: MapPin },
  { id: 'cards', name: 'Cards & Barcodes', icon: CreditCard },
  { id: 'security', name: 'Security & Privacy', icon: Shield },
  { id: 'billing', name: 'Billing & Subscriptions', icon: CreditCard },
  { id: 'technical', name: 'Technical', icon: Smartphone }
]

export default function SupportPage() {
  const [selectedCategory, setSelectedCategory] = useState<string>('all')
  const [openFAQ, setOpenFAQ] = useState<string | null>(null)

  const filteredFAQs = selectedCategory === 'all'
    ? faqs
    : faqs.filter(faq => faq.category === selectedCategory)

  const toggleFAQ = (id: string) => {
    setOpenFAQ(openFAQ === id ? null : id)
  }

  return (
    <div className="min-h-screen flex flex-col">
      <Header />

      <main className="flex-grow">
        {/* Hero Section */}
        <section className="bg-gradient-to-br from-blue-50 to-blue-100 dark:from-gray-900 dark:to-gray-800 py-20">
          <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              className="text-center"
            >
              <div className="inline-flex items-center justify-center w-16 h-16 bg-blue-100 dark:bg-blue-900 rounded-full mb-6">
                <HelpCircle className="w-8 h-8 text-blue-600" />
              </div>

              <h1 className="text-4xl md:text-5xl font-bold text-gray-900 dark:text-white mb-6">
                Support & <span className="text-blue-600">FAQ</span>
              </h1>
              <p className="text-xl text-gray-600 dark:text-gray-300 mb-8 max-w-2xl mx-auto">
                Find answers to common questions about CardOnCue. Can't find what you're looking for?
                Contact our support team.
              </p>

              <a
                href="/contact"
                className="btn-primary"
              >
                Contact Support
              </a>
            </motion.div>
          </div>
        </section>

        {/* FAQ Section */}
        <section className="py-20 bg-white dark:bg-gray-900">
          <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
            {/* Category Filter */}
            <div className="mb-12">
              <div className="flex flex-wrap justify-center gap-3">
                <button
                  onClick={() => setSelectedCategory('all')}
                  className={`px-4 py-2 rounded-full text-sm font-medium transition-colors duration-200 ${
                    selectedCategory === 'all'
                      ? 'bg-primary-600 text-white'
                      : 'bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700'
                  }`}
                >
                  All Questions
                </button>
                {categories.map((category) => (
                  <button
                    key={category.id}
                    onClick={() => setSelectedCategory(category.id)}
                    className={`px-4 py-2 rounded-full text-sm font-medium transition-colors duration-200 ${
                      selectedCategory === category.id
                        ? 'bg-primary-600 text-white'
                        : 'bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700'
                    }`}
                  >
                    {category.name}
                  </button>
                ))}
              </div>
            </div>

            {/* FAQ List */}
            <div className="space-y-4">
              {filteredFAQs.map((faq, index) => (
                <motion.div
                  key={faq.id}
                  initial={{ opacity: 0, y: 10 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  transition={{ duration: 0.3, delay: index * 0.05 }}
                  viewport={{ once: true }}
                  className="card"
                >
                  <button
                    onClick={() => toggleFAQ(faq.id)}
                    className="w-full flex items-center justify-between text-left"
                  >
                    <h3 className="text-lg font-medium text-gray-900 dark:text-white pr-4">
                      {faq.question}
                    </h3>
                    <ChevronDown
                      className={`w-5 h-5 text-gray-500 transition-transform duration-200 flex-shrink-0 ${
                        openFAQ === faq.id ? 'transform rotate-180' : ''
                      }`}
                    />
                  </button>

                  <AnimatePresence>
                    {openFAQ === faq.id && (
                      <motion.div
                        initial={{ opacity: 0, height: 0 }}
                        animate={{ opacity: 1, height: 'auto' }}
                        exit={{ opacity: 0, height: 0 }}
                        transition={{ duration: 0.3 }}
                        className="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700"
                      >
                        <p className="text-gray-600 dark:text-gray-300 leading-relaxed">
                          {faq.answer}
                        </p>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </motion.div>
              ))}
            </div>

            {filteredFAQs.length === 0 && (
              <div className="text-center py-12">
                <HelpCircle className="w-16 h-16 text-gray-300 dark:text-gray-600 mx-auto mb-4" />
                <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-2">
                  No questions found
                </h3>
                <p className="text-gray-600 dark:text-gray-300">
                  Try selecting a different category or contact support if you can't find what you're looking for.
                </p>
              </div>
            )}
          </div>
        </section>

        {/* Still Need Help */}
        <section className="py-20 bg-gray-50 dark:bg-gray-800">
          <div className="max-w-4xl mx-auto text-center px-4 sm:px-6 lg:px-8">
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.6 }}
              viewport={{ once: true }}
            >
              <h2 className="text-3xl md:text-4xl font-bold text-gray-900 dark:text-white mb-4">
                Still Need Help?
              </h2>
              <p className="text-xl text-gray-600 dark:text-gray-300 mb-8 max-w-2xl mx-auto">
                Can't find the answer you're looking for? Our support team is here to help.
              </p>

              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <a
                  href="/contact"
                  className="btn-primary"
                >
                  Contact Support
                </a>
                <a
                  href="mailto:hello@cardoncue.com"
                  className="btn-secondary"
                >
                  Email Us Directly
                </a>
              </div>

              <div className="mt-8 text-sm text-gray-500 dark:text-gray-400">
                <p>We typically respond within 24 hours during business days.</p>
              </div>
            </motion.div>
          </div>
        </section>
      </main>

      <Footer />
    </div>
  )
}
