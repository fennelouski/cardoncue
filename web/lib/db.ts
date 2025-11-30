import { createPool, type VercelPool } from '@vercel/postgres';

// Lazy pool creation to avoid build-time initialization
let _pool: VercelPool | null = null;

function getPool(): VercelPool {
  if (!_pool) {
    _pool = createPool({
      connectionString: process.env.POSTGRES_URL
    });
  }
  return _pool;
}

// Export pool with lazy initialization
export const pool = new Proxy({} as VercelPool, {
  get(target, prop) {
    return getPool()[prop as keyof VercelPool];
  }
});

// Export sql template for queries
export const sql = new Proxy({} as VercelPool['sql'], {
  get(target, prop) {
    return getPool().sql[prop as keyof VercelPool['sql']];
  },
  apply(target, thisArg, args) {
    return Reflect.apply(getPool().sql as any, thisArg, args);
  }
});
