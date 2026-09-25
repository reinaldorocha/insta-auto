import { Pool, type PoolClient, type QueryResult, type QueryResultRow } from "pg";
import { requireEnv } from "@/lib/env";

declare global {
  var postgresPool: Pool | undefined;
}

export const DB_SCHEMA = process.env.DATABASE_SCHEMA || "uaiflow";

const UAIFLOW_TABLES_PATTERN = /\bpublic\.(config|instagram_accounts|profile_settings|automations|followups|contacts|events|content_posts|queue|workspaces|workspace_members|profiles|claim_queue_jobs|set_updated_at)\b/g;

export function resolveSql(text: string): string {
  if (DB_SCHEMA === "public") return text;
  return text.replace(UAIFLOW_TABLES_PATTERN, (_match, table) => `${DB_SCHEMA}.${table}`);
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
  return getPool().query<T>(resolveSql(text), params);
}

export async function transaction<T>(
  work: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await getPool().connect();

  try {
    await client.query("begin");
    const originalQuery = client.query.bind(client);
    client.query = (async (sqlOrConfig: unknown, values?: unknown[]) => {
      if (typeof sqlOrConfig === "string") {
        return originalQuery(resolveSql(sqlOrConfig), values);
      }
      return originalQuery(sqlOrConfig as never, values as never);
    }) as typeof client.query;

    const result = await work(client);
    await originalQuery("commit");
    return result;
  } catch (error) {
    await client.query("rollback").catch(() => undefined);
    throw error;
  } finally {
    client.release();
  }
}