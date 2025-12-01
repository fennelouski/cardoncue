'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { Header } from '../components/Header'
import { Footer } from '../components/Footer'
import { Moon, Sun, Bell, Globe, ArrowLeft } from 'lucide-react'
import { useUser } from '@clerk/nextjs'
import { EmojiPicker } from '../components/EmojiPicker'

// Default emoji if none selected
const DEFAULT_EMOJI = '🐶'

export default function SettingsPage() {
  const { isSignedIn, user } = useUser()
  const [theme, setTheme] = useState<'light' | 'dark'>('dark')
  const [notifications, setNotifications] = useState(true)
  const [language, setLanguage] = useState('en')
  const [avatarEmoji, setAvatarEmoji] = useState(DEFAULT_EMOJI)
  const [saving, setSaving] = useState(false)

  // Load settings from Clerk metadata (authenticated) or localStorage (non-authenticated)
  useEffect(() => {
    if (isSignedIn && user) {
      // Load from Clerk user metadata
      const metadata = user.publicMetadata as any
      setTheme(metadata?.theme || 'dark')
      setNotifications(metadata?.notifications ?? true)
      setLanguage(metadata?.language || 'en')
    } else {
      // Load from localStorage for non-authenticated users
      const savedTheme = localStorage.getItem('theme') as 'light' | 'dark' | null
      const savedNotifications = localStorage.getItem('notifications')
      const savedLanguage = localStorage.getItem('language')
      const savedEmoji = localStorage.getItem('avatarEmoji')

      if (savedTheme) setTheme(savedTheme)
      if (savedNotifications) setNotifications(savedNotifications === 'true')
      if (savedLanguage) setLanguage(savedLanguage)
      if (savedEmoji) setAvatarEmoji(savedEmoji)
    }
  }, [isSignedIn, user])

  const handleThemeChange = (newTheme: 'light' | 'dark') => {
    setTheme(newTheme)
    document.documentElement.classList.toggle('dark', newTheme === 'dark')

    if (!isSignedIn) {
      localStorage.setItem('theme', newTheme)
    }
  }

  const handleNotificationsChange = (enabled: boolean) => {
    setNotifications(enabled)

    if (!isSignedIn) {
      localStorage.setItem('notifications', enabled.toString())
    }
  }

  const handleLanguageChange = (lang: string) => {
    setLanguage(lang)

    if (!isSignedIn) {
      localStorage.setItem('language', lang)
    }
  }

  const handleEmojiChange = (emoji: string) => {
    setAvatarEmoji(emoji)
    localStorage.setItem('avatarEmoji', emoji)
    // Force header to re-render with new emoji
    window.dispatchEvent(new Event('storage'))
  }

  const handleSaveSettings = async () => {
    if (!isSignedIn) {
      // For non-authenticated users, settings are already in localStorage
      alert('Settings saved locally!')
      return
    }

    setSaving(true)
    try {
      // Update Clerk user metadata
      await user?.update({
        unsafeMetadata: {
          theme,
          notifications,
          language,
        },
      })
      alert('Settings saved successfully!')
    } catch (error) {
      console.error('Error saving settings:', error)
      alert('Failed to save settings')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="min-h-screen flex flex-col bg-gray-50 dark:bg-gray-900">
      <Header />

      <main className="flex-grow py-12">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="mb-6">
            <Link
              href="/"
              className="inline-flex items-center text-primary-600 hover:text-primary-700 dark:text-primary-400"
            >
              <ArrowLeft className="w-4 h-4 mr-2" />
              Back to Home
            </Link>
          </div>

          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6 md:p-8">
            <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">
              App Settings
            </h1>
            <p className="text-gray-600 dark:text-gray-300 mb-8">
              {isSignedIn
                ? 'Manage your CardOnCue preferences. Changes are synced to your account.'
                : 'Manage your app preferences. Sign in to save your settings across devices.'
              }
            </p>

            <div className="space-y-6">
              {/* Avatar Emoji - Only for non-authenticated users */}
              {!isSignedIn && (
                <div className="border-b border-gray-200 dark:border-gray-700 pb-6">
                  <EmojiPicker selectedEmoji={avatarEmoji} onSelect={handleEmojiChange} />
                </div>
              )}

              {/* Theme Setting */}
              <div className="border-b border-gray-200 dark:border-gray-700 pb-6">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    {theme === 'dark' ? (
                      <Moon className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                    ) : (
                      <Sun className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                    )}
                    <div>
                      <h3 className="text-lg font-medium text-gray-900 dark:text-white">
                        Theme
                      </h3>
                      <p className="text-sm text-gray-500 dark:text-gray-400">
                        Choose your preferred color scheme
                      </p>
                    </div>
                  </div>
                  <div className="flex space-x-2">
                    <button
                      onClick={() => handleThemeChange('light')}
                      className={`px-4 py-2 rounded-lg transition-colors ${
                        theme === 'light'
                          ? 'bg-primary-600 text-white'
                          : 'bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300'
                      }`}
                    >
                      Light
                    </button>
                    <button
                      onClick={() => handleThemeChange('dark')}
                      className={`px-4 py-2 rounded-lg transition-colors ${
                        theme === 'dark'
                          ? 'bg-primary-600 text-white'
                          : 'bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300'
                      }`}
                    >
                      Dark
                    </button>
                  </div>
                </div>
              </div>

              {/* Notifications Setting */}
              <div className="border-b border-gray-200 dark:border-gray-700 pb-6">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <Bell className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                    <div>
                      <h3 className="text-lg font-medium text-gray-900 dark:text-white">
                        Notifications
                      </h3>
                      <p className="text-sm text-gray-500 dark:text-gray-400">
                        Enable browser notifications
                      </p>
                    </div>
                  </div>
                  <button
                    onClick={() => handleNotificationsChange(!notifications)}
                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                      notifications ? 'bg-primary-600' : 'bg-gray-300 dark:bg-gray-600'
                    }`}
                  >
                    <span
                      className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                        notifications ? 'translate-x-6' : 'translate-x-1'
                      }`}
                    />
                  </button>
                </div>
              </div>

              {/* Language Setting */}
              <div className="pb-6">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-3">
                    <Globe className="w-5 h-5 text-gray-600 dark:text-gray-400" />
                    <div>
                      <h3 className="text-lg font-medium text-gray-900 dark:text-white">
                        Language
                      </h3>
                      <p className="text-sm text-gray-500 dark:text-gray-400">
                        Select your preferred language
                      </p>
                    </div>
                  </div>
                  <select
                    value={language}
                    onChange={(e) => handleLanguageChange(e.target.value)}
                    className="px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
                  >
                    <option value="en">English</option>
                    <option value="es">Español</option>
                    <option value="fr">Français</option>
                    <option value="de">Deutsch</option>
                  </select>
                </div>
              </div>
            </div>

            {/* Save Button */}
            <div className="mt-8 flex justify-end">
              <button
                onClick={handleSaveSettings}
                disabled={saving}
                className="btn-primary px-8 py-3"
              >
                {saving ? 'Saving...' : 'Save Settings'}
              </button>
            </div>

            {/* Sign In CTA - Only show for non-authenticated users */}
            {!isSignedIn && (
              <div className="mt-8 p-4 bg-primary-50 dark:bg-primary-900/20 rounded-lg border border-primary-200 dark:border-primary-800">
                <h3 className="text-lg font-semibold text-primary-900 dark:text-primary-100 mb-2">
                  Want to sync your settings?
                </h3>
                <p className="text-primary-700 dark:text-primary-300 mb-4">
                  Sign in to sync your preferences across all your devices and access additional features.
                </p>
                <Link
                  href="/sign-in"
                  className="inline-block bg-primary-600 hover:bg-primary-700 text-white font-semibold px-6 py-2 rounded-lg transition-colors"
                >
                  Sign In
                </Link>
              </div>
            )}
          </div>
        </div>
      </main>

      <Footer />
    </div>
  )
}
