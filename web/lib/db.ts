import { createPool } from '@vercel/postgres';

// Create a pooled connection for serverless functions
// This uses POSTGRES_URL (pooled) by default
export const pool = createPool({
  connectionString: process.env.POSTGRES_URL
});

// Export sql template for queries
export const sql = pool.sql;
