'use client'

import { useState, useCallback, useMemo, useEffect, useRef } from 'react'
import { GoogleMap, LoadScript, Marker, Circle } from '@react-google-maps/api'
import { getDistance } from 'geolib'
import { Play, Pause } from 'lucide-react'

interface DemoLocation {
  id: string
  name: string
  lat: number
  lng: number
  radius: number
  cardName: string
  cardType: string
  brandColor?: string
}

const DEMO_LOCATIONS: DemoLocation[] = [
  {
    id: '1',
    name: 'Costco Wholesale',
    lat: 37.7749,
    lng: -122.4194,
    radius: 200,
    cardName: 'Costco Membership',
    cardType: 'membership',
    brandColor: '#0066B2'
  },
  {
    id: '2',
    name: 'SF Public Library',
    lat: 37.7799,
    lng: -122.4162,
    radius: 150,
    cardName: 'Library Card',
    cardType: 'library',
    brandColor: '#E63946'
  },
  {
    id: '3',
    name: '24 Hour Fitness',
    lat: 37.7849,
    lng: -122.4094,
    radius: 100,
    cardName: '24 Hour Fitness',
    cardType: 'gym',
    brandColor: '#FFB703'
  }
]

const DEFAULT_CENTER = {
  lat: 37.7799,
  lng: -122.4194
}

const mapContainerStyle = {
  width: '100%',
  height: '600px'
}

const mapOptions = {
  disableDefaultUI: false,
  zoomControl: true,
  mapTypeControl: false,
  streetViewControl: false,
  fullscreenControl: true
}

// Animation path through all geofences
const ANIMATION_PATH = [
  { lat: 37.7799, lng: -122.4294 }, // Start outside all zones
  { lat: 37.7799, lng: -122.4194 }, // Move towards Costco
  { lat: 37.7749, lng: -122.4194 }, // Enter Costco zone
  { lat: 37.7749, lng: -122.4144 }, // Move towards Library
  { lat: 37.7799, lng: -122.4162 }, // Enter Library zone
  { lat: 37.7824, lng: -122.4128 }, // Move towards Gym
  { lat: 37.7849, lng: -122.4094 }, // Enter Gym zone
  { lat: 37.7874, lng: -122.4044 }, // Exit all zones
  { lat: 37.7799, lng: -122.4294 }, // Return to start
]

export function GeofencingDemo() {
  const [userPosition, setUserPosition] = useState(DEFAULT_CENTER)
  const [isDragging, setIsDragging] = useState(false)
  const [isAutoPlaying, setIsAutoPlaying] = useState(true)
  const [pathIndex, setPathIndex] = useState(0)
  const animationFrameRef = useRef<number>()
  const lastUpdateRef = useRef<number>(Date.now())

  // Auto-play animation
  useEffect(() => {
    if (!isAutoPlaying || isDragging) {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current)
      }
      return
    }

    const animate = () => {
      const now = Date.now()
      const elapsed = now - lastUpdateRef.current

      // Update position every 50ms
      if (elapsed > 50) {
        setPathIndex((prevIndex) => {
          const nextIndex = (prevIndex + 1) % ANIMATION_PATH.length
          const targetPos = ANIMATION_PATH[nextIndex]
          const currentPos = ANIMATION_PATH[prevIndex]

          // Smooth interpolation between points
          const progress = Math.min(elapsed / 2000, 1) // 2 seconds per segment

          setUserPosition({
            lat: currentPos.lat + (targetPos.lat - currentPos.lat) * progress,
            lng: currentPos.lng + (targetPos.lng - currentPos.lng) * progress,
          })

          if (progress >= 1) {
            lastUpdateRef.current = now
            return nextIndex
          }
          return prevIndex
        })
      }

      animationFrameRef.current = requestAnimationFrame(animate)
    }

    animationFrameRef.current = requestAnimationFrame(animate)

    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current)
      }
    }
  }, [isAutoPlaying, isDragging])

  const handleUserMarkerDrag = useCallback((e: google.maps.MapMouseEvent) => {
    if (e.latLng) {
      setIsAutoPlaying(false)
      setUserPosition({
        lat: e.latLng.lat(),
        lng: e.latLng.lng()
      })
    }
  }, [])

  const activeCards = useMemo(() => {
    return DEMO_LOCATIONS.filter(location => {
      const distance = getDistance(
        { latitude: userPosition.lat, longitude: userPosition.lng },
        { latitude: location.lat, longitude: location.lng }
      )
      return distance <= location.radius
    })
  }, [userPosition])

  return (
    <div className="w-full">
      <div className="mb-6">
        <div className="flex items-center justify-between mb-2">
          <h2 className="text-2xl font-bold text-gray-900 dark:text-white">
            Interactive Geofencing Demo
          </h2>
          <button
            onClick={() => setIsAutoPlaying(!isAutoPlaying)}
            className="flex items-center gap-2 px-4 py-2 bg-primary-600 hover:bg-primary-700 text-white rounded-lg transition-colors"
          >
            {isAutoPlaying ? (
              <>
                <Pause className="w-4 h-4" />
                Pause
              </>
            ) : (
              <>
                <Play className="w-4 h-4" />
                Play
              </>
            )}
          </button>
        </div>
        <p className="text-gray-600 dark:text-gray-400">
          {isAutoPlaying
            ? 'Watch as the user moves through different locations and cards automatically appear on the lock screen.'
            : 'Drag the blue marker to manually move the user position and see cards appear when entering geofenced areas.'}
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Map Section */}
        <div className="lg:col-span-2">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg overflow-hidden">
            <LoadScript googleMapsApiKey={process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || ''}>
              <GoogleMap
                mapContainerStyle={mapContainerStyle}
                center={userPosition}
                zoom={14}
                options={mapOptions}
              >
                {/* Location markers and geofence circles */}
                {DEMO_LOCATIONS.map(location => (
                  <div key={location.id}>
                    <Circle
                      center={{ lat: location.lat, lng: location.lng }}
                      radius={location.radius}
                      options={{
                        fillColor: location.brandColor || '#4285F4',
                        fillOpacity: 0.2,
                        strokeColor: location.brandColor || '#4285F4',
                        strokeOpacity: 0.8,
                        strokeWeight: 2
                      }}
                    />
                    <Marker
                      position={{ lat: location.lat, lng: location.lng }}
                      title={location.name}
                      icon={{
                        path: google.maps.SymbolPath.CIRCLE,
                        scale: 8,
                        fillColor: location.brandColor || '#4285F4',
                        fillOpacity: 1,
                        strokeColor: '#FFFFFF',
                        strokeWeight: 2
                      }}
                    />
                  </div>
                ))}

                {/* User position marker (draggable) */}
                <Marker
                  position={userPosition}
                  draggable={true}
                  onDrag={handleUserMarkerDrag}
                  onDragStart={() => setIsDragging(true)}
                  onDragEnd={() => setIsDragging(false)}
                  title="Your Position (Drag me!)"
                  icon={{
                    path: google.maps.SymbolPath.CIRCLE,
                    scale: 12,
                    fillColor: '#1E88E5',
                    fillOpacity: 1,
                    strokeColor: '#FFFFFF',
                    strokeWeight: 3
                  }}
                />
              </GoogleMap>
            </LoadScript>
          </div>

          {/* Legend */}
          <div className="mt-4 bg-white dark:bg-gray-800 rounded-lg shadow p-4">
            <h3 className="font-semibold text-gray-900 dark:text-white mb-3">Legend</h3>
            <div className="space-y-2 text-sm">
              <div className="flex items-center gap-2">
                <div className="w-4 h-4 rounded-full bg-blue-600 border-2 border-white"></div>
                <span className="text-gray-700 dark:text-gray-300">Your Position (Draggable)</span>
              </div>
              {DEMO_LOCATIONS.map(location => (
                <div key={location.id} className="flex items-center gap-2">
                  <div
                    className="w-4 h-4 rounded-full border-2 border-white"
                    style={{ backgroundColor: location.brandColor }}
                  ></div>
                  <span className="text-gray-700 dark:text-gray-300">
                    {location.name} ({location.radius}m radius)
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Lock Screen Simulation */}
        <div className="lg:col-span-1">
          <div className="sticky top-4">
            <div className="bg-gradient-to-b from-gray-900 to-gray-800 rounded-3xl shadow-2xl overflow-hidden border-8 border-gray-900">
              {/* iPhone Lock Screen Header */}
              <div className="bg-gradient-to-b from-gray-900/50 to-transparent pt-4 pb-8 px-6">
                <div className="flex justify-between items-center text-white text-sm mb-8">
                  <span className="font-medium">9:41</span>
                  <div className="flex gap-1 items-center">
                    <div className="w-4 h-3 border border-white rounded-sm"></div>
                    <div className="w-1 h-3 bg-white rounded-sm"></div>
                  </div>
                </div>
                <div className="text-center text-white">
                  <div className="text-6xl font-light mb-2">
                    {new Date().getHours()}:{String(new Date().getMinutes()).padStart(2, '0')}
                  </div>
                  <div className="text-lg">
                    {new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}
                  </div>
                </div>
              </div>

              {/* Cards Section */}
              <div className="px-4 pb-6 space-y-3 min-h-[300px]">
                {activeCards.length === 0 ? (
                  <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-6 text-center">
                    <p className="text-white/60 text-sm">
                      No cards nearby. Drag the blue marker into a colored circle to see cards appear.
                    </p>
                  </div>
                ) : (
                  activeCards.map(location => (
                    <div
                      key={location.id}
                      className="bg-white/90 backdrop-blur-lg rounded-2xl p-4 shadow-lg animate-in slide-in-from-top duration-300"
                    >
                      <div className="flex items-start gap-3">
                        <div
                          className="w-12 h-12 rounded-lg flex items-center justify-center text-white font-bold text-lg"
                          style={{ backgroundColor: location.brandColor }}
                        >
                          {location.cardName.charAt(0)}
                        </div>
                        <div className="flex-1">
                          <div className="font-semibold text-gray-900">{location.cardName}</div>
                          <div className="text-sm text-gray-600">{location.name}</div>
                          <div className="text-xs text-gray-500 mt-1">
                            {location.cardType}
                          </div>
                        </div>
                      </div>
                    </div>
                  ))
                )}
              </div>

              {/* Lock Screen Bottom */}
              <div className="flex justify-center pb-6">
                <div className="w-32 h-1 bg-white/30 rounded-full"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
