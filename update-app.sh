#!/usr/bin/env bash
# ==============================================================================
# Script de Atualização Contínua: UaiFlow
# ==============================================================================
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}             ATUALIZANDO UAIFLOW NA VPS                     ${NC}"
echo -e "${CYAN}============================================================${NC}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# 1. Puxar alterações do repositório Git
echo -e "${BLUE}[1/4] Puxando alterações do Git...${NC}"
git pull origin main

# 2. Recompilar e reiniciar containers da aplicação
echo -e "${BLUE}[2/4] Recompilando containers da aplicação...${NC}"
docker compose up -d --build

# 3. Aplicar novas migrations no schema uaiflow
echo -e "${BLUE}[3/4] Sincronizando migrations do schema uaiflow...${NC}"
docker compose exec app node scripts/migrate.cjs || true

# 4. Notificar reload de schema no PostgREST
DB_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'supabase.*db|supabase-postgres|postgres:17' | head -n1)
if [ -n "$DB_CONTAINER" ]; then
  docker exec -i "$DB_CONTAINER" psql -U postgres -d postgres -c "SELECT pg_notify('pgrst', 'reload schema');" > /dev/null 2>&1 || true
fi

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}            UAIFLOW ATUALIZADO COM SUCESSO!                 ${NC}"
echo -e "${GREEN}============================================================${NC}"
echo -e "Acompanhe os logs da aplicação com: ${CYAN}docker compose logs -f app${NC}"
