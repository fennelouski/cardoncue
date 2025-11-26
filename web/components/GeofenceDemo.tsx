'use client';

import { useEffect, useRef, useState } from 'react';

// Extend Window interface for Google Maps
declare global {
  interface Window {
    google: any;
  }
}

type NotificationType = 'costco' | 'library' | 'gym' | null;

// City-specific location data
const CITY_LOCATIONS: Record<string, {
  name: string;
  center: { lat: number; lng: number };
  costco: { name: string; lat: number; lng: number; radius: number };
  library: { name: string; lat: number; lng: number; radius: number };
  gym: { name: string; lat: number; lng: number; radius: number };
}> = {
  'san-francisco': {
    name: 'San Francisco',
    center: { lat: 37.7774, lng: -122.4167 },
    costco: { name: 'Costco Wholesale', lat: 37.7749, lng: -122.4194, radius: 100 },
    library: { name: 'SF Public Library', lat: 37.7799, lng: -122.4134, radius: 80 },
    gym: { name: '24 Hour Fitness', lat: 37.7824, lng: -122.4100, radius: 75 },
  },
  'los-angeles': {
    name: 'Los Angeles',
    center: { lat: 34.0522, lng: -118.2437 },
    costco: { name: 'Costco Los Angeles', lat: 34.0522, lng: -118.2437, radius: 100 },
    library: { name: 'LA Public Library', lat: 34.0580, lng: -118.2480, radius: 80 },
    gym: { name: 'LA Fitness', lat: 34.0600, lng: -118.2400, radius: 75 },
  },
  'seattle': {
    name: 'Seattle',
    center: { lat: 47.6062, lng: -122.3321 },
    costco: { name: 'Costco Seattle', lat: 47.6062, lng: -122.3321, radius: 100 },
    library: { name: 'Seattle Public Library', lat: 47.6105, lng: -122.3320, radius: 80 },
    gym: { name: 'Seattle Fitness', lat: 47.6080, lng: -122.3280, radius: 75 },
  },
  'denver': {
    name: 'Denver',
    center: { lat: 39.7392, lng: -104.9903 },
    costco: { name: 'Costco Denver', lat: 39.7392, lng: -104.9903, radius: 100 },
    library: { name: 'Denver Public Library', lat: 39.7442, lng: -104.9880, radius: 80 },
    gym: { name: '24 Hour Fitness', lat: 39.7370, lng: -104.9850, radius: 75 },
  },
  'phoenix': {
    name: 'Phoenix',
    center: { lat: 33.4484, lng: -112.0740 },
    costco: { name: 'Costco Phoenix', lat: 33.4484, lng: -112.0740, radius: 100 },
    library: { name: 'Phoenix Public Library', lat: 33.4520, lng: -112.0710, radius: 80 },
    gym: { name: 'Phoenix Fitness', lat: 33.4500, lng: -112.0680, radius: 75 },
  },
  'chicago': {
    name: 'Chicago',
    center: { lat: 41.8781, lng: -87.6298 },
    costco: { name: 'Costco Chicago', lat: 41.8781, lng: -87.6298, radius: 100 },
    library: { name: 'Chicago Public Library', lat: 41.8819, lng: -87.6278, radius: 80 },
    gym: { name: 'Chicago Fitness', lat: 41.8800, lng: -87.6250, radius: 75 },
  },
  'dallas': {
    name: 'Dallas',
    center: { lat: 32.7767, lng: -96.7970 },
    costco: { name: 'Costco Dallas', lat: 32.7767, lng: -96.7970, radius: 100 },
    library: { name: 'Dallas Public Library', lat: 32.7817, lng: -96.7970, radius: 80 },
    gym: { name: 'Dallas Fitness', lat: 32.7790, lng: -96.7940, radius: 75 },
  },
  'new-york': {
    name: 'New York',
    center: { lat: 40.7128, lng: -74.0060 },
    costco: { name: 'Costco New York', lat: 40.7128, lng: -74.0060, radius: 100 },
    library: { name: 'NY Public Library', lat: 40.7532, lng: -73.9822, radius: 80 },
    gym: { name: 'Equinox', lat: 40.7580, lng: -73.9800, radius: 75 },
  },
  'boston': {
    name: 'Boston',
    center: { lat: 42.3601, lng: -71.0589 },
    costco: { name: 'Costco Boston', lat: 42.3601, lng: -71.0589, radius: 100 },
    library: { name: 'Boston Public Library', lat: 42.3493, lng: -71.0779, radius: 80 },
    gym: { name: 'Boston Sports Club', lat: 42.3550, lng: -71.0650, radius: 75 },
  },
  'miami': {
    name: 'Miami',
    center: { lat: 25.7617, lng: -80.1918 },
    costco: { name: 'Costco Miami', lat: 25.7617, lng: -80.1918, radius: 100 },
    library: { name: 'Miami Public Library', lat: 25.7743, lng: -80.1937, radius: 80 },
    gym: { name: 'LA Fitness Miami', lat: 25.7680, lng: -80.1900, radius: 75 },
  },
  'honolulu': {
    name: 'Honolulu',
    center: { lat: 21.3099, lng: -157.8581 },
    costco: { name: 'Costco Honolulu', lat: 21.3099, lng: -157.8581, radius: 100 },
    library: { name: 'Hawaii State Library', lat: 21.3069, lng: -157.8583, radius: 80 },
    gym: { name: '24 Hour Fitness', lat: 21.3080, lng: -157.8550, radius: 75 },
  },
  'anchorage': {
    name: 'Anchorage',
    center: { lat: 61.2181, lng: -149.9003 },
    costco: { name: 'Costco Anchorage', lat: 61.2181, lng: -149.9003, radius: 100 },
    library: { name: 'Anchorage Public Library', lat: 61.2176, lng: -149.8897, radius: 80 },
    gym: { name: 'Alaska Fitness', lat: 61.2200, lng: -149.8950, radius: 75 },
  },
  'london': {
    name: 'London',
    center: { lat: 51.5074, lng: -0.1278 },
    costco: { name: 'Costco London', lat: 51.5074, lng: -0.1278, radius: 100 },
    library: { name: 'British Library', lat: 51.5299, lng: -0.1270, radius: 80 },
    gym: { name: 'Virgin Active', lat: 51.5150, lng: -0.1250, radius: 75 },
  },
  'paris': {
    name: 'Paris',
    center: { lat: 48.8566, lng: 2.3522 },
    costco: { name: 'Costco Paris', lat: 48.8566, lng: 2.3522, radius: 100 },
    library: { name: 'Bibliothèque Nationale', lat: 48.8338, lng: 2.3765, radius: 80 },
    gym: { name: 'Basic Fit', lat: 48.8450, lng: 2.3600, radius: 75 },
  },
  'tokyo': {
    name: 'Tokyo',
    center: { lat: 35.6762, lng: 139.6503 },
    costco: { name: 'Costco Tokyo', lat: 35.6762, lng: 139.6503, radius: 100 },
    library: { name: 'National Diet Library', lat: 35.6786, lng: 139.7440, radius: 80 },
    gym: { name: 'Gold\'s Gym', lat: 35.6800, lng: 139.7000, radius: 75 },
  },
  'sydney': {
    name: 'Sydney',
    center: { lat: -33.8688, lng: 151.2093 },
    costco: { name: 'Costco Sydney', lat: -33.8688, lng: 151.2093, radius: 100 },
    library: { name: 'State Library of NSW', lat: -33.8688, lng: 151.2106, radius: 80 },
    gym: { name: 'Fitness First', lat: -33.8700, lng: 151.2080, radius: 75 },
  },
};

// Map timezones to cities
const TIMEZONE_TO_CITY: Record<string, string> = {
  // Pacific Time
  'America/Los_Angeles': 'los-angeles',
  'America/Vancouver': 'seattle',
  'America/Tijuana': 'los-angeles',

  // Mountain Time
  'America/Denver': 'denver',
  'America/Phoenix': 'phoenix',
  'America/Boise': 'denver',

  // Central Time
  'America/Chicago': 'chicago',
  'America/Mexico_City': 'dallas',
  'America/Winnipeg': 'chicago',

  // Eastern Time
  'America/New_York': 'new-york',
  'America/Toronto': 'new-york',
  'America/Detroit': 'new-york',
  'America/Boston': 'boston',
  'America/Miami': 'miami',

  // Hawaii
  'Pacific/Honolulu': 'honolulu',

  // Alaska
  'America/Anchorage': 'anchorage',

  // Europe
  'Europe/London': 'london',
  'Europe/Paris': 'paris',
  'Europe/Berlin': 'paris',
  'Europe/Madrid': 'paris',

  // Asia
  'Asia/Tokyo': 'tokyo',
  'Asia/Seoul': 'tokyo',
  'Asia/Shanghai': 'tokyo',

  // Australia
  'Australia/Sydney': 'sydney',
  'Australia/Melbourne': 'sydney',
};

function detectCity(): string {
  try {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    return TIMEZONE_TO_CITY[timezone] || 'san-francisco';
  } catch {
    return 'san-francisco';
  }
}

// Load Google Maps script
function loadGoogleMapsScript(): Promise<void> {
  return new Promise((resolve, reject) => {
    if (typeof window.google !== 'undefined') {
      resolve();
      return;
    }

    const script = document.createElement('script');
    script.src = `https://maps.googleapis.com/maps/api/js?key=${process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || 'AIzaSyBw5PjUKBVHZgT-VlB7v9tW_kgNhY3xF8Y'}`;
    script.async = true;
    script.defer = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error('Failed to load Google Maps'));
    document.head.appendChild(script);
  });
}

export default function GeofenceDemo() {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstanceRef = useRef<any>(null);
  const userMarkerRef = useRef<any>(null);
  const [notification, setNotification] = useState<NotificationType>(null);
  const [currentTime, setCurrentTime] = useState('');
  const [cityKey] = useState(() => detectCity());
  const [isMapLoaded, setIsMapLoaded] = useState(false);

  // Get city data
  const cityData = CITY_LOCATIONS[cityKey];
  const COSTCO = { ...cityData.costco, type: 'costco' };
  const LIBRARY = { ...cityData.library, type: 'library' };
  const GYM = { ...cityData.gym, type: 'gym' };

  // Update time every second
  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      const hours = now.getHours();
      const minutes = now.getMinutes().toString().padStart(2, '0');
      const period = hours >= 12 ? 'PM' : 'AM';
      const displayHours = hours % 12 || 12;
      setCurrentTime(`${displayHours}:${minutes} ${period}`);
    };
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  useEffect(() => {
    if (typeof window === 'undefined' || !mapRef.current || isMapLoaded) return;

    loadGoogleMapsScript().then(() => {
      if (!mapRef.current || mapInstanceRef.current) return;

      // Initialize map
      const map = new window.google.maps.Map(mapRef.current, {
        center: cityData.center,
        zoom: 16, // Zoomed in more
        disableDefaultUI: true,
        zoomControl: false,
        mapTypeControl: false,
        scaleControl: false,
        streetViewControl: false,
        rotateControl: false,
        fullscreenControl: false,
        gestureHandling: 'none',
        styles: [
          {
            featureType: 'poi',
            stylers: [{ visibility: 'simplified' }]
          }
        ]
      });
      mapInstanceRef.current = map;
      setIsMapLoaded(true);

      // Add markers with custom colors
      const createMarker = (location: any, color: string) => {
        const marker = new window.google.maps.Marker({
          position: { lat: location.lat, lng: location.lng },
          map,
          icon: {
            path: window.google.maps.SymbolPath.CIRCLE,
            scale: 10,
            fillColor: color,
            fillOpacity: 1,
            strokeColor: 'white',
            strokeWeight: 3,
          },
          title: location.name,
        });

        // Add geofence circle
        new window.google.maps.Circle({
          map,
          center: { lat: location.lat, lng: location.lng },
          radius: location.radius,
          fillColor: color,
          fillOpacity: 0.1,
          strokeColor: color,
          strokeOpacity: 0.3,
          strokeWeight: 2,
        });

        return marker;
      };

      // Add location markers
      createMarker(COSTCO, '#0070f3');
      createMarker(LIBRARY, '#8b5cf6');
      createMarker(GYM, '#f59e0b');

      // User marker
      const userMarker = new window.google.maps.Marker({
        position: { lat: COSTCO.lat - 0.001, lng: COSTCO.lng },
        map,
        icon: {
          path: window.google.maps.SymbolPath.CIRCLE,
          scale: 8,
          fillColor: '#10b981',
          fillOpacity: 1,
          strokeColor: 'white',
          strokeWeight: 3,
        },
        zIndex: 1000,
      });
      userMarkerRef.current = userMarker;

      // Generate waypoints for all three locations
      const startOffset = 0.001;
      const latDiffLibrary = LIBRARY.lat - COSTCO.lat;
      const lngDiffLibrary = LIBRARY.lng - COSTCO.lng;
      const latDiffGym = GYM.lat - LIBRARY.lat;
      const lngDiffGym = GYM.lng - LIBRARY.lng;

      const waypoints = [
        // Approach Costco
        { lat: COSTCO.lat - startOffset, lng: COSTCO.lng, delay: 0 },
        { lat: COSTCO.lat - (startOffset * 0.5), lng: COSTCO.lng, delay: 2000 },
        { lat: COSTCO.lat - (startOffset * 0.2), lng: COSTCO.lng, delay: 2000, trigger: 'costco' },
        { lat: COSTCO.lat + (startOffset * 0.3), lng: COSTCO.lng, delay: 2000 },
        // Move to library
        { lat: COSTCO.lat + (latDiffLibrary * 0.3), lng: COSTCO.lng + (lngDiffLibrary * 0.3), delay: 3000 },
        { lat: COSTCO.lat + (latDiffLibrary * 0.6), lng: COSTCO.lng + (lngDiffLibrary * 0.6), delay: 2000 },
        { lat: COSTCO.lat + (latDiffLibrary * 0.9), lng: COSTCO.lng + (lngDiffLibrary * 0.9), delay: 2000 },
        { lat: LIBRARY.lat - (startOffset * 0.1), lng: LIBRARY.lng, delay: 2000, trigger: 'library' },
        { lat: LIBRARY.lat + (startOffset * 0.3), lng: LIBRARY.lng, delay: 2000 },
        // Move to gym
        { lat: LIBRARY.lat + (latDiffGym * 0.3), lng: LIBRARY.lng + (lngDiffGym * 0.3), delay: 3000 },
        { lat: LIBRARY.lat + (latDiffGym * 0.6), lng: LIBRARY.lng + (lngDiffGym * 0.6), delay: 2000 },
        { lat: LIBRARY.lat + (latDiffGym * 0.9), lng: LIBRARY.lng + (lngDiffGym * 0.9), delay: 2000 },
        { lat: GYM.lat - (startOffset * 0.1), lng: GYM.lng, delay: 2000, trigger: 'gym' },
        { lat: GYM.lat, lng: GYM.lng, delay: 3000 },
      ];

      let currentWaypoint = 0;
      const animateUser = () => {
        if (currentWaypoint >= waypoints.length) {
          currentWaypoint = 0; // Loop
        }

        const point = waypoints[currentWaypoint];
        userMarker.setPosition({ lat: point.lat, lng: point.lng });

        // Trigger notification
        if (point.trigger) {
          setNotification(point.trigger as NotificationType);
          setTimeout(() => setNotification(null), 3000);
        }

        currentWaypoint++;
        setTimeout(animateUser, point.delay);
      };

      // Start animation
      setTimeout(animateUser, 1000);
    }).catch((error) => {
      console.error('Failed to load Google Maps:', error);
    });

    return () => {
      if (mapInstanceRef.current) {
        mapInstanceRef.current = null;
      }
    };
  }, [cityData, COSTCO, LIBRARY, GYM, isMapLoaded]);

  return (
    <div className="relative w-full h-full flex gap-6 items-start justify-center">
      {/* Map Section - Same size as phone */}
      <div className="w-[280px] flex-shrink-0">
        <div className="relative bg-gray-200 dark:bg-gray-700 rounded-[40px] p-3 shadow-2xl" style={{ aspectRatio: '9/19.5' }}>
          <div ref={mapRef} className="w-full h-full rounded-[32px]" />
        </div>
      </div>

      {/* Mock iPhone Section */}
      <div className="w-[280px] flex-shrink-0">
        <div className="relative bg-black rounded-[40px] p-3 shadow-2xl" style={{ aspectRatio: '9/19.5' }}>
          {/* Dynamic Island */}
          <div className="absolute top-3 left-1/2 -translate-x-1/2 w-32 h-8 bg-black rounded-full z-10" />

          {/* Lock Screen */}
          <div className="relative h-full bg-gradient-to-br from-blue-900 via-purple-900 to-pink-900 rounded-[32px] overflow-hidden">
            {/* Time */}
            <div className="absolute top-16 left-0 right-0 text-center">
              <div className="text-white text-6xl font-light tracking-tight">
                {currentTime.split(' ')[0]}
              </div>
              <div className="text-white/70 text-lg mt-1">
                {new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}
              </div>
            </div>

            {/* Notifications - All appear in same position */}
            <div className="absolute top-48 left-4 right-4">
              {/* Costco Notification */}
              <div
                className={`absolute inset-0 transform transition-all duration-500 ${
                  notification === 'costco'
                    ? 'translate-y-0 opacity-100'
                    : '-translate-y-4 opacity-0 pointer-events-none'
                }`}
              >
                <div className="bg-white/95 backdrop-blur-xl rounded-2xl p-4 shadow-lg">
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 bg-blue-500 rounded-lg flex items-center justify-center flex-shrink-0">
                      <span className="text-white text-xl">🏪</span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-semibold text-gray-900 text-sm">CardOnCue</div>
                      <div className="text-gray-600 text-xs mt-0.5">Your Costco membership card is ready</div>
                      <div className="mt-2 bg-gradient-to-r from-blue-500 to-blue-600 rounded-lg p-3 text-white">
                        <div className="text-xs font-medium">COSTCO WHOLESALE</div>
                        <div className="text-lg font-bold mt-1">**** **** 1234</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Library Notification */}
              <div
                className={`absolute inset-0 transform transition-all duration-500 ${
                  notification === 'library'
                    ? 'translate-y-0 opacity-100'
                    : '-translate-y-4 opacity-0 pointer-events-none'
                }`}
              >
                <div className="bg-white/95 backdrop-blur-xl rounded-2xl p-4 shadow-lg">
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 bg-purple-500 rounded-lg flex items-center justify-center flex-shrink-0">
                      <span className="text-white text-xl">📚</span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-semibold text-gray-900 text-sm">CardOnCue</div>
                      <div className="text-gray-600 text-xs mt-0.5">Your library card is ready</div>
                      <div className="mt-2 bg-gradient-to-r from-purple-500 to-purple-600 rounded-lg p-3 text-white">
                        <div className="text-xs font-medium">{LIBRARY.name.toUpperCase()}</div>
                        <div className="text-lg font-bold mt-1">**** **** 5678</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              {/* Gym Notification */}
              <div
                className={`absolute inset-0 transform transition-all duration-500 ${
                  notification === 'gym'
                    ? 'translate-y-0 opacity-100'
                    : '-translate-y-4 opacity-0 pointer-events-none'
                }`}
              >
                <div className="bg-white/95 backdrop-blur-xl rounded-2xl p-4 shadow-lg">
                  <div className="flex items-start gap-3">
                    <div className="w-10 h-10 bg-orange-500 rounded-lg flex items-center justify-center flex-shrink-0">
                      <span className="text-white text-xl">💪</span>
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-semibold text-gray-900 text-sm">CardOnCue</div>
                      <div className="text-gray-600 text-xs mt-0.5">Your gym membership is ready</div>
                      <div className="mt-2 bg-gradient-to-r from-orange-500 to-orange-600 rounded-lg p-3 text-white">
                        <div className="text-xs font-medium">{GYM.name.toUpperCase()}</div>
                        <div className="text-lg font-bold mt-1">**** **** 9012</div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
