'use client'

import { EmojiPixelAvatar } from './EmojiPixelAvatar'

interface EmojiPickerProps {
  selectedEmoji: string
  onSelect: (emoji: string) => void
}

// Curated list of fun emoji options (fruits, animals, objects, vehicles)
const EMOJI_OPTIONS = [
  // Fruits
  '🍎', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓',
  // Animals
  '🐶', '🐱', '🐼', '🐨', '🦊', '🐧', '🐸', '🐢', '🐝', '🦋', '🐙', '🦀',
  // Objects
  '☕', '🎸', '🎮', '📚', '⚡', '🎁', '🎨',
  // Vehicles
  '🚗', '🚀', '🛸', '✈️'
]

export function EmojiPicker({ selectedEmoji, onSelect }: EmojiPickerProps) {
  return (
    <div>
      <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-3">
        Choose Your Avatar
      </h3>
      <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">
        Select an emoji for your pixelated avatar. This is stored locally until you sign in.
      </p>

      <div className="grid grid-cols-6 sm:grid-cols-8 md:grid-cols-10 gap-2">
        {EMOJI_OPTIONS.map((emoji) => (
          <button
            key={emoji}
            onClick={() => onSelect(emoji)}
            className={`
              relative p-2 rounded-lg border-2 transition-all
              ${selectedEmoji === emoji
                ? 'border-primary-600 bg-primary-50 dark:bg-primary-900/20'
                : 'border-gray-200 dark:border-gray-700 hover:border-primary-400'
              }
            `}
            title={emoji}
          >
            <div className="flex items-center justify-center">
              <EmojiPixelAvatar emoji={emoji} size={32} gridSize={20} />
            </div>
          </button>
        ))}
      </div>

      {selectedEmoji && (
        <div className="mt-6 p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
          <p className="text-sm text-gray-600 dark:text-gray-400 mb-3">
            Your selected avatar (preview at different sizes):
          </p>
          <div className="flex items-center gap-4">
            <EmojiPixelAvatar emoji={selectedEmoji} size={24} gridSize={20} />
            <EmojiPixelAvatar emoji={selectedEmoji} size={32} gridSize={25} />
            <EmojiPixelAvatar emoji={selectedEmoji} size={48} gridSize={25} />
            <EmojiPixelAvatar emoji={selectedEmoji} size={64} gridSize={25} />
          </div>
        </div>
      )}
    </div>
  )
}
