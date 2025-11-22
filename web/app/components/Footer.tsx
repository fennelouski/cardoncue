import Link from 'next/link'
import { Github, Twitter, Mail } from 'lucide-react'

export function Footer() {
  const navigation = {
    main: [
      { name: 'Home', href: '/' },
      { name: 'Features', href: '/features' },
      { name: 'Support', href: '/support' },
      { name: 'Contact', href: '/contact' },
    ],
    legal: [
      { name: 'Privacy Policy', href: '/privacy' },
      { name: 'Terms of Use', href: '/terms' },
    ],
    social: [
      {
        name: 'Twitter',
        href: '#',
        icon: Twitter,
      },
      {
        name: 'GitHub',
        href: '#',
        icon: Github,
      },
      {
        name: 'Email',
        href: 'mailto:hello@cardoncue.com',
        icon: Mail,
      },
    ],
  }

  return (
    <footer className="bg-gray-50 dark:bg-gray-900 border-t border-gray-200 dark:border-gray-800">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          {/* Brand */}
          <div className="col-span-1 md:col-span-2">
            <div className="flex items-center space-x-2 mb-4">
              <div className="w-8 h-8 bg-primary-600 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-sm">C</span>
              </div>
              <span className="font-bold text-xl text-gray-900 dark:text-white">
                CardOnCue
              </span>
            </div>
            <p className="text-gray-600 dark:text-gray-300 mb-4 max-w-md">
              Automatically show your membership cards, library cards, and barcodes
              when you enter relevant locations. Never fumble for your wallet again.
            </p>
            <div className="flex space-x-4">
              {navigation.social.map((item) => (
                <a
                  key={item.name}
                  href={item.href}
                  className="text-gray-400 hover:text-gray-500 dark:hover:text-gray-300 transition-colors duration-200"
                >
                  <span className="sr-only">{item.name}</span>
                  <item.icon className="h-6 w-6" />
                </a>
              ))}
            </div>
          </div>

          {/* Navigation */}
          <div>
            <h3 className="text-sm font-semibold text-gray-900 dark:text-white uppercase tracking-wider mb-4">
              Navigation
            </h3>
            <ul className="space-y-2">
              {navigation.main.map((item) => (
                <li key={item.name}>
                  <Link
                    href={item.href}
                    className="text-gray-600 hover:text-gray-900 dark:text-gray-300 dark:hover:text-white transition-colors duration-200"
                  >
                    {item.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Legal */}
          <div>
            <h3 className="text-sm font-semibold text-gray-900 dark:text-white uppercase tracking-wider mb-4">
              Legal
            </h3>
            <ul className="space-y-2">
              {navigation.legal.map((item) => (
                <li key={item.name}>
                  <Link
                    href={item.href}
                    className="text-gray-600 hover:text-gray-900 dark:text-gray-300 dark:hover:text-white transition-colors duration-200"
                  >
                    {item.name}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* App Store Links */}
        <div className="mt-8 pt-8 border-t border-gray-200 dark:border-gray-700">
          <div className="flex flex-col sm:flex-row justify-between items-center">
            <div className="flex flex-col sm:flex-row items-center space-y-4 sm:space-y-0 sm:space-x-4 mb-4 sm:mb-0">
              <a
                href="#"
                className="bg-black text-white px-6 py-2 rounded-lg hover:bg-gray-800 transition-colors duration-200 text-sm font-medium"
              >
                Download on the App Store
              </a>
              <Link
                href="/android"
                className="text-primary-600 hover:text-primary-700 font-medium text-sm"
              >
                Android Version Coming Soon →
              </Link>
            </div>

            <p className="text-sm text-gray-500 dark:text-gray-400">
              © 2024 CardOnCue. All rights reserved.
            </p>
          </div>
        </div>
      </div>
    </footer>
  )
}
