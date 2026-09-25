const { createPool, ensureMigrationsTable, getMigrations } = require("./migration-utils.cjs");

const MIGRATION_LOCK_ID = 1_905_202_600;

async function main() {
  const migrations = getMigrations();
  const pool = createPool();
  const client = await pool.connect();

  try {
    await client.query("select pg_advisory_lock($1)", [MIGRATION_LOCK_ID]);
    await ensureMigrationsTable(client);
    const { rows } = await client.query("select version, name, checksum from uaiflow.schema_migrations order by version");
    const applied = new Map(rows.map((row) => [row.version, row]));
    let count = 0;

    for (const migration of migrations) {
      const existing = applied.get(migration.version);
      if (existing) {
        if (existing.name !== migration.name || existing.checksum !== migration.checksum) {
          throw new Error(`A migration ${migration.version} foi alterada depois de aplicada. Restaure o arquivo original e crie uma nova migration.`);
        }
        console.log(`[ok] ${migration.name} ja aplicada`);
        continue;
      }

      console.log(`[aplicando] ${migration.name}`);
      await client.query("begin");
      try {
        await client.query("set local lock_timeout = '10s'");
        await client.query("set local statement_timeout = '5min'");
        await client.query(migration.sql);
        await client.query(
          "insert into uaiflow.schema_migrations (version, name, checksum) values ($1, $2, $3)",
          [migration.version, migration.name, migration.checksum],
        );
        await client.query("commit");
        count += 1;
        console.log(`[aplicada] ${migration.name}`);
      } catch (error) {
        await client.query("rollback");
        throw error;
      }
    }

    console.log(count ? `${count} migration(s) aplicada(s) com sucesso.` : "Banco atualizado. Nenhuma migration pendente.");
  } finally {
    await client.query("select pg_advisory_unlock($1)", [MIGRATION_LOCK_ID]).catch(() => undefined);
    client.release();
    await pool.end();
  }
}

main().catch((error) => {
  console.error(`Falha ao aplicar migrations: ${error.message}`);
  process.exitCode = 1;
});