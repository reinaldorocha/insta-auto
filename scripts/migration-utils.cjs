const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const MIGRATION_FILE_PATTERN = /^\d{4}_[a-z0-9_]+\.sql$/;

function loadEnvFile(file = path.join(process.cwd(), ".env.local")) {
  if (!fs.existsSync(file)) return false;

  for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
    if (!line || line.trim().startsWith("#")) continue;
    const index = line.indexOf("=");
    if (index === -1) continue;
    const key = line.slice(0, index).trim();
    const value = line.slice(index + 1).trim().replace(/^"|"$/g, "");
    if (!process.env[key]) process.env[key] = value;
  }

  return true;
}

function getMigrations() {
  const directory = path.join(process.cwd(), "supabase", "migrations");
  if (!fs.existsSync(directory)) {
    throw new Error(`Diretorio de migrations nao encontrado: ${directory}`);
  }

  const files = fs.readdirSync(directory)
    .filter((file) => MIGRATION_FILE_PATTERN.test(file))
    .sort((left, right) => left.localeCompare(right));

  if (!files.length) {
    throw new Error("Nenhuma migration foi encontrada em supabase/migrations.");
  }

  return files.map((file) => {
    const sql = fs.readFileSync(path.join(directory, file), "utf8");
    return {
      version: file.slice(0, 4),
      name: file,
      sql,
      checksum: crypto.createHash("sha256").update(sql).digest("hex"),
    };
  });
}

function createPool() {
  loadEnvFile();
  if (!process.env.DATABASE_URL) {
    throw new Error("DATABASE_URL nao configurada. Copie .env.example para .env.local e preencha a conexao do Supabase.");
  }

  const { Pool } = require("pg");
  return new Pool({
    connectionString: process.env.DATABASE_URL,
    max: 1,
    connectionTimeoutMillis: 10_000,
    ssl: { rejectUnauthorized: false },
  });
}

async function ensureMigrationsTable(client) {
  await client.query(`
    create table if not exists public.schema_migrations (
      version text primary key,
      name text not null unique,
      checksum text not null,
      applied_at timestamptz not null default now()
    )
  `);
}

module.exports = {
  createPool,
  ensureMigrationsTable,
  getMigrations,
  loadEnvFile,
};