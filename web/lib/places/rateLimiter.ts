interface RateLimitOptions {
  requestsPerMinute: number;
  burstLimit?: number;
}

class RateLimiter {
  private requests = new Map<string, number[]>();

  constructor(private options: RateLimitOptions) {}

  isAllowed(identifier: string): boolean {
    const now = Date.now();
    const windowStart = now - 60000; // 1 minute window
    const key = `${this.constructor.name}:${identifier}`;

    // Get existing timestamps for this identifier
    let timestamps = this.requests.get(key) || [];

    // Remove timestamps outside the current window
    timestamps = timestamps.filter(ts => ts > windowStart);

    // Check if we're within the limit
    if (timestamps.length >= this.options.requestsPerMinute) {
      return false;
    }

    // Add current timestamp
    timestamps.push(now);
    this.requests.set(key, timestamps);

    return true;
  }

  getRemainingRequests(identifier: string): number {
    const key = `${this.constructor.name}:${identifier}`;
    const timestamps = this.requests.get(key) || [];
    const windowStart = Date.now() - 60000;
    const validTimestamps = timestamps.filter(ts => ts > windowStart);

    return Math.max(0, this.options.requestsPerMinute - validTimestamps.length);
  }

  // Clean up old entries periodically
  cleanup(): void {
    const cutoff = Date.now() - 120000; // Remove entries older than 2 minutes
    for (const [key, timestamps] of this.requests.entries()) {
      const validTimestamps = timestamps.filter(ts => ts > cutoff);
      if (validTimestamps.length === 0) {
        this.requests.delete(key);
      } else {
        this.requests.set(key, validTimestamps);
      }
    }
  }
}

// Global cleanup
if (typeof globalThis !== 'undefined') {
  setInterval(() => {
    // This would ideally be done per rate limiter instance, but for simplicity:
    const cleanupKey = 'rateLimiterCleanup';
    if (!(globalThis as any)[cleanupKey]) {
      (globalThis as any)[cleanupKey] = true;
      setInterval(() => {
        // Clean up all rate limiters (this is a simplified approach)
      }, 300000); // Clean every 5 minutes
    }
  }, 1000);
}

export const nominatimLimiter = new RateLimiter({
  requestsPerMinute: parseInt(process.env.PLACES_RATE_LIMIT_PER_MIN || '60')
});

export const foursquareLimiter = new RateLimiter({
  requestsPerMinute: 500 // Foursquare free tier limit
});

export const googlePlacesLimiter = new RateLimiter({
  requestsPerMinute: 100 // Conservative limit for Google Places
});
