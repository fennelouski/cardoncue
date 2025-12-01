'use client'

import { useEffect, useRef } from 'react'

interface EmojiPixelAvatarProps {
  emoji: string
  size?: number
  gridSize?: number
  className?: string
}

export function EmojiPixelAvatar({
  emoji,
  size = 32,
  gridSize = 25,
  className = ''
}: EmojiPixelAvatarProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null)

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext('2d', { willReadFrequently: true })
    if (!ctx) return

    // Set canvas size
    const pixelSize = Math.ceil(size / gridSize)
    const actualSize = pixelSize * gridSize
    canvas.width = actualSize
    canvas.height = actualSize

    // Clear canvas
    ctx.clearRect(0, 0, actualSize, actualSize)

    // Draw emoji on a temporary canvas
    const tempCanvas = document.createElement('canvas')
    const tempSize = 128 // Higher resolution for better emoji rendering
    tempCanvas.width = tempSize
    tempCanvas.height = tempSize
    const tempCtx = tempCanvas.getContext('2d')
    if (!tempCtx) return

    // Draw emoji centered on temp canvas
    tempCtx.fillStyle = 'transparent'
    tempCtx.fillRect(0, 0, tempSize, tempSize)
    tempCtx.font = `${tempSize * 0.8}px Arial`
    tempCtx.textAlign = 'center'
    tempCtx.textBaseline = 'middle'
    tempCtx.fillText(emoji, tempSize / 2, tempSize / 2)

    // Get image data
    const imageData = tempCtx.getImageData(0, 0, tempSize, tempSize)
    const data = imageData.data

    // Pixelate: sample grid and draw blocky squares
    for (let y = 0; y < gridSize; y++) {
      for (let x = 0; x < gridSize; x++) {
        // Sample from center of each grid cell in the temp canvas
        const sampleX = Math.floor((x + 0.5) * (tempSize / gridSize))
        const sampleY = Math.floor((y + 0.5) * (tempSize / gridSize))
        const index = (sampleY * tempSize + sampleX) * 4

        const r = data[index]
        const g = data[index + 1]
        const b = data[index + 2]
        const a = data[index + 3]

        // Only draw if pixel has some opacity
        if (a > 30) {
          // Draw blocky square with slight gap for pixel effect
          const gap = 1
          ctx.fillStyle = `rgba(${r}, ${g}, ${b}, ${a / 255})`
          ctx.fillRect(
            x * pixelSize + gap,
            y * pixelSize + gap,
            pixelSize - gap * 2,
            pixelSize - gap * 2
          )
        }
      }
    }
  }, [emoji, size, gridSize])

  return (
    <canvas
      ref={canvasRef}
      className={className}
      style={{
        width: size,
        height: size,
        imageRendering: 'pixelated'
      }}
    />
  )
}
