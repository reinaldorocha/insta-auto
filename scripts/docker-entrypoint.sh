#!/bin/sh
set -e

# Executa migrations automaticamente se AUTO_MIGRATE=true ou nao definido
if [ "$AUTO_MIGRATE" != "false" ] && [ -n "$DATABASE_URL" ]; then
  echo "[entrypoint] Verificando migrations do Supabase/Postgres..."
  node scripts/migrate.cjs || echo "[entrypoint] Aviso: Falha ao rodar migrations automaticas. Voce pode rodar manualmente depois."
fi

exec "$@"