'use client'

import { UserButton } from '@clerk/nextjs'
import Link from 'next/link'
import { useUser } from '@clerk/nextjs'
import { useState, useEffect } from 'react'
import { EmojiPixelAvatar } from './EmojiPixelAvatar'

// Default emoji if none selected
const DEFAULT_EMOJI = '🐶'

export function ProfileButton() {
  const { isSignedIn } = useUser()
  const [avatarEmoji, setAvatarEmoji] = useState(DEFAULT_EMOJI)

  // Load avatar emoji from localStorage
  useEffect(() => {
    const saved = localStorage.getItem('avatarEmoji')
    if (saved) {
      setAvatarEmoji(saved)
    }

    // Listen for storage changes to update avatar in real-time
    const handleStorageChange = () => {
      const newEmoji = localStorage.getItem('avatarEmoji')
      if (newEmoji) {
        setAvatarEmoji(newEmoji)
      }
    }

    window.addEventListener('storage', handleStorageChange)
    return () => window.removeEventListener('storage', handleStorageChange)
  }, [])

  if (!isSignedIn) {
    // Non-authenticated users see pixelated emoji avatar
    return (
      <Link
        href="/settings"
        className="flex items-center space-x-2 hover:opacity-80 transition-opacity"
        title="Settings"
      >
        <div className="rounded-full overflow-hidden bg-gray-100 dark:bg-gray-800 p-0.5">
          <EmojiPixelAvatar emoji={avatarEmoji} size={32} gridSize={25} />
        </div>
        <span className="hidden sm:inline text-gray-600 dark:text-gray-300">Settings</span>
      </Link>
    )
  }

  // Authenticated users see Clerk's UserButton
  return (
    <div className="flex items-center space-x-2">
      <UserButton
        afterSignOutUrl="/"
        appearance={{
          elements: {
            avatarBox: "w-8 h-8"
          }
        }}
      />
    </div>
  )
}
