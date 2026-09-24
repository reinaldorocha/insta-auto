import { Pool, type PoolClient, type QueryResult, type QueryResultRow } from "pg";
import { requireEnv } from "@/lib/env";

declare global {
  var postgresPool: Pool | undefined;
}

export function getPool(): Pool {
  if (!globalThis.postgresPool) {
    const ssl =
      process.env.DATABASE_SSL === "false" || process.env.DATABASE_SSL === "0"
        ? false
        : { rejectUnauthorized: false };

    globalThis.postgresPool = new Pool({
      connectionString: requireEnv("DATABASE_URL"),
      max: Math.max(1, Number(process.env.DATABASE_POOL_MAX || 10)),
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 5_000,
      ssl,
    });
  }
  return globalThis.postgresPool;
}

export const pool = new Proxy({} as Pool, {
  get(_target, prop, receiver) {
    const p = getPool();
    const value = Reflect.get(p, prop, receiver);
    if (typeof value === "function") {
      return value.bind(p);
    }
    return value;
  },
});

export async function query<T extends QueryResultRow = QueryResultRow>(
  text: string,
  params: unknown[] = [],
): Promise<QueryResult<T>> {
  return getPool().query<T>(text, params);
}

export async function transaction<T>(
  work: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await getPool().connect();

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