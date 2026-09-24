#!/usr/bin/env bash
# ==============================================================================
# UaiFlow - Script de Instalação e Configuração Automática na VPS com Docker
# Detecta automaticamente o Supabase existente e configura o ambiente sem esforço.
# ==============================================================================

set -e

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # Sem cor

clear
echo -e "${CYAN}${BOLD}"
echo "===================================================================="
echo "    🚀 UaiFlow - Instalador Automático na VPS (Docker + Supabase)   "
echo "===================================================================="
echo -e "${NC}"

# 1. Checar se Docker e Docker Compose estão instalados
if ! command -v docker &> /dev/null; then
  echo -e "${RED}[X] Docker não está instalado nesta máquina.${NC}"
  exit 1
fi

echo -e "${BLUE}[*] Analisando containers em execução na sua VPS...${NC}"

# 2. Detecção automática dos containers do Supabase
DB_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'supabase.*db|supabase-postgres|postgres:17' | head -n1)
AUTH_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'supabase.*auth|gotrue' | head -n1)
STUDIO_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'supabase.*studio' | head -n1)
STORAGE_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'supabase.*storage' | head -n1)
REST_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'supabase.*rest|postgrest' | head -n1)
ENVOY_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'supabase.*envoy|supabase.*kong' | head -n1)
NPM_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E 'nginx-proxy-manager|root-app' | head -n1)

# Detectar IP público da VPS
HOST_IP=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || curl -s --max-time 3 https://ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

# 3. Extrair credenciais do Postgres automaticamente
DETECTED_DB_PASS=""
if [ -n "$DB_CONTAINER" ]; then
  DETECTED_DB_PASS=$(docker inspect "$DB_CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -E '^POSTGRES_PASSWORD=' | head -n1 | cut -d= -f2- | tr -d '"')
fi
if [ -z "$DETECTED_DB_PASS" ] && [ -n "$REST_CONTAINER" ]; then
  DETECTED_DB_PASS=$(docker inspect "$REST_CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -E '^PGRST_DB_URI=' | sed -E 's/.*postgres:([^@]+)@.*/\1/' | head -n1 | tr -d '"')
fi
if [ -z "$DETECTED_DB_PASS" ] && [ -n "$AUTH_CONTAINER" ]; then
  DETECTED_DB_PASS=$(docker inspect "$AUTH_CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -E '^GOTRUE_DB_DATABASE_URL=' | sed -E 's/.*postgres:([^@]+)@.*/\1/' | head -n1 | tr -d '"')
fi

# Detectar porta do pooler / postgres exposta
POOLER_PORT=$(docker ps --format '{{.Ports}}' | grep -oE '[0-9]+->5432/tcp' | cut -d- -f1 | head -n1)
if [ -z "$POOLER_PORT" ]; then
  POOLER_PORT="54322"
fi

# 4. Extrair ANON_KEY e SERVICE_ROLE_KEY automaticamente
DETECTED_ANON_KEY=""
DETECTED_SERVICE_KEY=""

if [ -n "$STUDIO_CONTAINER" ]; then
  DETECTED_ANON_KEY=$(docker inspect "$STUDIO_CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -E '^(SUPABASE_)?ANON_KEY=' | head -n1 | cut -d= -f2- | tr -d '"')
  DETECTED_SERVICE_KEY=$(docker inspect "$STUDIO_CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -E '^(SUPABASE_)?SERVICE_KEY=' | head -n1 | cut -d= -f2- | tr -d '"')
fi
if [ -z "$DETECTED_ANON_KEY" ] && [ -n "$STORAGE_CONTAINER" ]; then
  DETECTED_ANON_KEY=$(docker inspect "$STORAGE_CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -E '^ANON_KEY=' | head -n1 | cut -d= -f2- | tr -d '"')
fi
if [ -z "$DETECTED_SERVICE_KEY" ] && [ -n "$STORAGE_CONTAINER" ]; then
  DETECTED_SERVICE_KEY=$(docker inspect "$STORAGE_CONTAINER" --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -E '^SERVICE_KEY=' | head -n1 | cut -d= -f2- | tr -d '"')
fi

# Detectar porta do Envoy / Kong
ENVOY_PORT=$(docker ps --format '{{.Ports}}' | grep -oE '[0-9]+->8000/tcp' | cut -d- -f1 | head -n1)
if [ -z "$ENVOY_PORT" ]; then
  ENVOY_PORT="8800"
fi

# Status da detecção
if [ -n "$DETECTED_DB_PASS" ]; then
  echo -e "${GREEN}[✓] Senha do Postgres do Supabase detectada automaticamente!${NC}"
else
  echo -e "${YELLOW}[!] Não foi possível extrair a senha do Postgres automaticamente.${NC}"
fi

if [ -n "$DETECTED_ANON_KEY" ]; then
  echo -e "${GREEN}[✓] Chave ANON_KEY do Supabase detectada automaticamente!${NC}"
fi

if [ -n "$DETECTED_SERVICE_KEY" ]; then
  echo -e "${GREEN}[✓] Chave SERVICE_ROLE_KEY do Supabase detectada automaticamente!${NC}"
fi

if [ -n "$NPM_CONTAINER" ]; then
  echo -e "${GREEN}[✓] Nginx Proxy Manager detectado ($NPM_CONTAINER)!${NC}"
fi

echo ""
echo -e "${BOLD}--- Configuração Guiada ---${NC}"
echo "Preencha apenas o domínio. O restante foi detectado ou será gerado automaticamente."
echo ""

# 5. Perguntar Domínio do UaiFlow
read -r -p "1. Qual domínio você vai usar para o UaiFlow? (ex: insta.meudominio.com): " INPUT_DOMAIN
if [ -z "$INPUT_DOMAIN" ]; then
  echo -e "${RED}Erro: O domínio é obrigatório para configurar as URLs do Instagram e Nginx.${NC}"
  exit 1
fi
# Remove http:// ou https:// e barras finais
CLEAN_DOMAIN=$(echo "$INPUT_DOMAIN" | sed -E 's|^https?://||' | sed -E 's|/+$||')
APP_BASE_URL="https://$CLEAN_DOMAIN"

# 6. Perguntar/Confirmar URL do Supabase
DEFAULT_SUPABASE_URL="http://${HOST_IP}:${ENVOY_PORT}"
read -r -p "2. URL pública do Supabase [Padrão: $DEFAULT_SUPABASE_URL]: " INPUT_SUPABASE_URL
SUPABASE_URL="${INPUT_SUPABASE_URL:-$DEFAULT_SUPABASE_URL}"
SUPABASE_URL=$(echo "$SUPABASE_URL" | sed -E 's|/+$||')
if [[ ! "$SUPABASE_URL" =~ ^https?:// ]]; then
  SUPABASE_URL="https://$SUPABASE_URL"
fi
NEXT_PUBLIC_SUPABASE_URL="$SUPABASE_URL"

# 7. Perguntar/Confirmar Senha do Postgres se não detectada
if [ -z "$DETECTED_DB_PASS" ]; then
  read -r -s -p "Senha do PostgreSQL do Supabase: " INPUT_DB_PASS
  echo ""
  DB_PASS="$INPUT_DB_PASS"
else
  DB_PASS="$DETECTED_DB_PASS"
fi

# 8. Perguntar/Confirmar Anon e Service Role Key se não detectadas
if [ -z "$DETECTED_ANON_KEY" ]; then
  read -r -p "Chave ANON_KEY do Supabase: " INPUT_ANON_KEY
  ANON_KEY="$INPUT_ANON_KEY"
else
  ANON_KEY="$DETECTED_ANON_KEY"
fi

if [ -z "$DETECTED_SERVICE_KEY" ]; then
  read -r -p "Chave SERVICE_ROLE_KEY do Supabase: " INPUT_SERVICE_KEY
  SERVICE_KEY="$INPUT_SERVICE_KEY"
else
  SERVICE_KEY="$DETECTED_SERVICE_KEY"
fi

# 9. Perguntar Senha Admin do UaiFlow
DEFAULT_ADMIN_PASS="UaiFlow$(openssl rand -hex 4 | tr '[:lower:]' '[:upper:]')!2026"
read -r -p "3. Senha de Admin do UaiFlow [ENTER para gerar: $DEFAULT_ADMIN_PASS]: " INPUT_ADMIN_PASS
ADMIN_PASSWORD="${INPUT_ADMIN_PASS:-$DEFAULT_ADMIN_PASS}"

# 10. Perguntar Meta App ID e Secret (opcionais no momento)
echo ""
echo -e "${YELLOW}Credenciais da Meta (Instagram Developer):${NC}"
echo "Se você ainda não criou o App na Meta, aperte ENTER em branco para configurar depois."
read -r -p "Meta App ID (opcional): " INPUT_META_ID
read -r -p "Meta App Secret (opcional): " INPUT_META_SECRET

META_ID="${INPUT_META_ID:-preencher_depois_no_env}"
META_SECRET="${INPUT_META_SECRET:-preencher_depois_no_env}"

# 11. Gerar segredos criptográficos automaticamente (32 bytes = 64 hex chars)
echo ""
echo -e "${BLUE}[*] Gerando segredos criptográficos de alta segurança...${NC}"
ADMIN_SESSION_SECRET=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p | tr -d '\n')
WORKER_SECRET=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p | tr -d '\n')
WEBHOOK_VERIFY_TOKEN=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p | tr -d '\n')

# 12. Montar DATABASE_URL
DATABASE_URL="postgresql://postgres:${DB_PASS}@host.docker.internal:${POOLER_PORT}/postgres"

# 13. Gravar o arquivo .env
echo -e "${BLUE}[*] Gravando arquivo .env...${NC}"

cat <<EOF > .env
# ==============================================================================
# UaiFlow - Configuração Gerada Automaticamente pelo Instalador
# ==============================================================================

# Supabase Auth e API
NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL}
NEXT_PUBLIC_SUPABASE_ANON_KEY=${ANON_KEY}
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_SERVICE_ROLE_KEY=${SERVICE_KEY}

# Banco de Dados Postgres (Supabase Self-Hosted)
DATABASE_URL=${DATABASE_URL}
DATABASE_SSL=false
DATABASE_POOL_MAX=5

# Aplicação
APP_BASE_URL=${APP_BASE_URL}

# Acesso Administrativo
ADMIN_PASSWORD=${ADMIN_PASSWORD}
ADMIN_SESSION_SECRET=${ADMIN_SESSION_SECRET}

# Worker interno (Fila e Webhook)
WORKER_SECRET=${WORKER_SECRET}

# Meta / Instagram Graph API
META_API_VERSION=v25.0
INSTAGRAM_APP_ID=${META_ID}
INSTAGRAM_APP_SECRET=${META_SECRET}
INSTAGRAM_REDIRECT_URI=${APP_BASE_URL}/api/oauth/callback
WEBHOOK_VERIFY_TOKEN=${WEBHOOK_VERIFY_TOKEN}
EOF

echo -e "${GREEN}[✓] Arquivo .env criado com sucesso!${NC}"

# 14. Compilar e subir containers
echo ""
read -r -p "Deseja iniciar o UaiFlow agora com Docker Compose? [S/n]: " START_NOW
START_NOW="${START_NOW:-S}"

if [[ "$START_NOW" =~ ^[Ss]$ ]]; then
  echo -e "${BLUE}[*] Construindo e iniciando containers (isso pode levar de 1 a 2 minutos)...${NC}"
  docker compose up -d --build
  echo -e "${GREEN}[✓] Containers iniciados com sucesso!${NC}"
fi

# 15. Exibir Resumo Final
echo ""
echo -e "${CYAN}${BOLD}====================================================================${NC}"
echo -e "${GREEN}${BOLD}           🎉 INSTALAÇÃO DO UAIFLOW CONCLUÍDA!                      ${NC}"
echo -e "${CYAN}${BOLD}====================================================================${NC}"
echo ""
echo -e "${BOLD}📌 DADOS DE ACESSO:${NC}"
echo -e "  • URL do App:        ${CYAN}${APP_BASE_URL}${NC}"
echo -e "  • Senha do Admin:    ${YELLOW}${ADMIN_PASSWORD}${NC}"
echo ""
echo -e "${BOLD}🌐 CONFIGURAÇÃO NO NGINX PROXY MANAGER (Porta 81):${NC}"
echo -e "  1. Acesse o painel do Nginx Proxy Manager."
echo -e "  2. Vá em 'Proxy Hosts' -> 'Add Proxy Host'."
echo -e "  3. Preencha:"
echo -e "     - Domain Names:          ${BOLD}${CLEAN_DOMAIN}${NC}"
echo -e "     - Scheme:                ${BOLD}http${NC}"
echo -e "     - Forward Hostname / IP: ${BOLD}172.17.0.1${NC}"
echo -e "     - Forward Port:          ${BOLD}3020${NC}"
echo -e "     - Marcar: [x] Block Common Exploits  [x] Websockets Support"
echo -e "  4. Na aba SSL:"
echo -e "     - Selecione: 'Request a new SSL Certificate' (Let's Encrypt)"
echo -e "     - Marcar: [x] Force SSL  [x] HTTP/2 Support"
echo ""
echo -e "${BOLD}🔑 DADOS PARA O META FOR DEVELOPERS (Instagram App):${NC}"
echo -e "  • OAuth Redirect URI:       ${CYAN}${APP_BASE_URL}/api/oauth/callback${NC}"
echo -e "  • Webhook Callback URL:     ${CYAN}${APP_BASE_URL}/api/webhook${NC}"
echo -e "  • Webhook Verify Token:     ${YELLOW}${WEBHOOK_VERIFY_TOKEN}${NC}"
echo -e "  • Política de Privacidade:  ${CYAN}${APP_BASE_URL}/privacidade${NC}"
echo -e "  • Exclusão de Dados:        ${CYAN}${APP_BASE_URL}/exclusao-de-dados${NC}"
echo ""
echo -e "${BOLD}⚙️  GERENCIAMENTO:${NC}"
echo -e "  • Ver logs:           ${BOLD}docker compose logs -f app${NC}"
echo -e "  • Reiniciar:          ${BOLD}docker compose restart${NC}"
echo -e "  • Parar:              ${BOLD}docker compose down${NC}"
echo -e "${CYAN}====================================================================${NC}"
