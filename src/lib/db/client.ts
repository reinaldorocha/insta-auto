import { Pool, type PoolClient, type QueryResult, type QueryResultRow } from "pg";
import { requireEnv } from "@/lib/env";

declare global {
  var postgresPool: Pool | undefined;
}

function createPool() {
  return new Pool({
    connectionString: requireEnv("DATABASE_URL"),
    max: Number(process.env.DATABASE_POOL_MAX || 1),
    idleTimeoutMillis: 5_000,
    connectionTimeoutMillis: 5_000,
    ssl: { rejectUnauthorized: false },
  });
}

export const pool = globalThis.postgresPool ?? createPool();

if (process.env.NODE_ENV !== "production") {
  globalThis.postgresPool = pool;
}

export async function query<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params: unknown[] = [],
): Promise<QueryResult<T>> {
  return pool.query<T>(text, params);
}

export async function transaction<T>(
  work: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();

  try {
    await client.query("begin");
    const result = await work(client);
    await client.query("commit");
    return result;
  } catch (error) {
    await client.query("rollback");
    throw error;
  } finally {
    client.release();
  }
}
