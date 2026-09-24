# 1. Base Node 22 Alpine (suporte oficial @supabase/supabase-js)
FROM node:22-alpine AS base
RUN apk add --no-cache libc6-compat
WORKDIR /app

# 2. Dependencias
FROM base AS deps
COPY package.json package-lock.json ./
RUN npm ci

# 3. Build da aplicacao
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Argumentos de build para variaveis publicas
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=$NEXT_PUBLIC_SUPABASE_ANON_KEY

# Variaveis dummy para permitir coleta estatica do Next.js sem falhar
ENV DATABASE_URL="postgresql://placeholder:placeholder@localhost:5432/placeholder"
ENV SUPABASE_URL="https://placeholder.supabase.co"
ENV SUPABASE_SERVICE_ROLE_KEY="placeholder_service_key"
ENV APP_BASE_URL="http://127.0.0.1:3000"
ENV ADMIN_PASSWORD="placeholder_admin_pass"
ENV ADMIN_SESSION_SECRET="placeholder_session_secret_32_chars_min"
ENV WORKER_SECRET="placeholder_worker_secret_32_chars_min"
ENV INSTAGRAM_APP_ID="placeholder_app_id"
ENV INSTAGRAM_APP_SECRET="placeholder_app_secret"
ENV INSTAGRAM_REDIRECT_URI="http://127.0.0.1:3000/api/oauth/callback"
ENV WEBHOOK_VERIFY_TOKEN="placeholder_webhook_token_32_chars_min"

ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

RUN npm run build

# 4. Imagem final enxuta de producao
FROM node:22-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Arquivos de runtime do Next standalone
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Scripts e migrations do Supabase
COPY --from=builder --chown=nextjs:nodejs /app/scripts ./scripts
COPY --from=builder --chown=nextjs:nodejs /app/supabase ./supabase
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json

# Entrypoint script
COPY --chown=nextjs:nodejs scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER nextjs

EXPOSE 3000

ENTRYPOINT ["/bin/sh", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["node", "server.js"]