import { kv } from '@vercel/kv';

interface CacheOptions {
  ttlSeconds?: number;
}

class PlacesCache {
  private inMemoryCache = new Map<string, { data: any; expires: number }>();
  private useVercelKV: boolean;

  constructor() {
    // Check if Vercel KV is available
    this.useVercelKV = !!process.env.KV_URL || !!process.env.REDIS_URL;
  }

  async get<T>(key: string): Promise<T | null> {
    try {
      if (this.useVercelKV) {
        const data = await kv.get<T>(key);
        return data;
      } else {
        // In-memory fallback for development
        const cached = this.inMemoryCache.get(key);
        if (cached && Date.now() < cached.expires) {
          return cached.data;
        } else if (cached) {
          this.inMemoryCache.delete(key);
        }
        return null;
      }
    } catch (error) {
      console.warn('Cache get error:', error);
      return null;
    }
  }

  async set<T>(key: string, data: T, ttlSeconds: number = 86400): Promise<void> {
    try {
      const expires = Date.now() + (ttlSeconds * 1000);

      if (this.useVercelKV) {
        await kv.setex(key, ttlSeconds, data);
      } else {
        // In-memory fallback for development
        this.inMemoryCache.set(key, { data, expires });
      }
    } catch (error) {
      console.warn('Cache set error:', error);
      // Fallback to in-memory even if Vercel KV fails
      const expires = Date.now() + (ttlSeconds * 1000);
      this.inMemoryCache.set(key, { data, expires });
    }
  }

  async delete(key: string): Promise<void> {
    try {
      if (this.useVercelKV) {
        await kv.del(key);
      } else {
        this.inMemoryCache.delete(key);
      }
    } catch (error) {
      console.warn('Cache delete error:', error);
    }
  }

  // Clean up expired entries in in-memory cache (called periodically)
  cleanup(): void {
    if (!this.useVercelKV) {
      const now = Date.now();
      for (const [key, value] of this.inMemoryCache.entries()) {
        if (now > value.expires) {
          this.inMemoryCache.delete(key);
        }
      }
    }
  }
}

export const placesCache = new PlacesCache();

// Periodically cleanup in-memory cache (only in development)
if (typeof globalThis !== 'undefined' && !process.env.KV_URL && !process.env.REDIS_URL) {
  setInterval(() => placesCache.cleanup(), 60000); // Clean every minute
}
