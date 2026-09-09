import { drizzle } from "drizzle-orm/node-postgres";
import pg from "pg";
import * as schema from "@shared/schema";

const { Pool } = pg;

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL must be set");
}

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
});

// Prevent unhandled 'error' events from crashing the process when
// PostgreSQL terminates idle connections (e.g. during admin commands / DB restarts).
pool.on('error', (err) => {
  console.error('[pg pool] idle client error — will reconnect on next query:', err.message);
});

export const db = drizzle(pool, { schema });
