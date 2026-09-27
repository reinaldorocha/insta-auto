# UaiFlow

Plataforma open source para automacoes de Instagram em PT-BR. O UaiFlow conecta contas profissionais do Instagram, recebe webhooks da Meta e executa respostas a comentarios, DMs, links, follow-ups e publicacoes.

## Quero instalar minha propria copia

Se voce nao e programador, siga este documento do inicio ao fim:

**[Guia completo para um novo proprietario](docs/GUIA_COMPLETO_NOVO_PROPRIETARIO.md)**

Cada instalacao usa banco, credenciais e conta do Instagram proprios; nenhum dado do dono anterior e copiado.

## Stack

- Next.js App Router e TypeScript
- Tailwind CSS
- Supabase Auth e Postgres
- Vercel
- Meta/Instagram Graph API com Instagram Login

## Instalacao tecnica resumida

```bash
npm install
cp .env.example .env.local
npm run setup:check
npm run db:migrate
npm run dev
```

No Windows PowerShell, use `Copy-Item .env.example .env.local`. Acesse `http://127.0.0.1:3000`.

## Comandos

```bash
npm run dev           # desenvolvimento local
npm run build         # build de producao
npm run start         # inicia o build local
npm run lint          # lint
npm run setup:check   # valida variaveis de ambiente
npm run db:migrate    # aplica migrations pendentes
npm run db:status     # mostra migrations aplicadas/pendentes
npm run release:check # verifica o pacote antes de publicar
```

`npm run db:apply` continua disponivel como alias de `db:migrate`.

## 🗄️ Arquitetura de Isolamento de Banco (Multi-App / Schemas)

O UaiFlow utiliza o schema dedicado **`uaiflow`** dentro do PostgreSQL do Supabase. Isso permite rodar múltiplos aplicativos na mesma VPS (por exemplo, **UaiFlow** e **Quiz App**) compartilhando a mesma instância de banco de dados e PostgREST com total isolamento e economia de recursos.

### Estrutura de Schemas:
- **`uaiflow`**: Contém todas as tabelas do UaiFlow (`uaiflow.automations`, `uaiflow.instagram_accounts`, `uaiflow.profiles`, `uaiflow.workspaces`, `uaiflow.queue`, etc.).
- **`quiz`**: Contém as tabelas da plataforma de quizzes (`quiz.quizzes`, `quiz.workspaces`, etc.).
- **`auth.users`**: Compartilhado com segurança pelo Supabase Auth.
- **`public`**: Permanece limpo para extensões do PostgreSQL.

### PostgREST (`PGRST_DB_SCHEMAS`)
O PostgREST expõe os schemas necessários para que os apps consumam suas APIs REST:
```env
PGRST_DB_SCHEMAS="public,storage,graphql_public,uaiflow,quiz"
```

---

## 🖥️ Instalação Automática na VPS (Docker + Supabase)

O UaiFlow conta com um script de instalação completo que detecta automaticamente se o Supabase e o Nginx Proxy Manager já estão rodando na VPS:

```bash
cd /var/www
git clone https://github.com/reinaldorocha/insta.git uaiflow
cd uaiflow
chmod +x install.sh update-app.sh
sudo ./install.sh
```

O instalador irá:
1. Detectar os containers do Supabase (porta 54322, chaves JWT, credenciais).
2. Criar o arquivo `.env` seguro com senhas e segredos criptográficos.
3. Subir a aplicação Next.js e o worker de filas via Docker Compose.
4. Conectar os containers na rede interna do Supabase e do Nginx Proxy Manager.
5. Aplicar as migrations no schema `uaiflow` e habilitar o schema no PostgREST com reload automático.

---

## 🚀 Como Atualizar o UaiFlow na VPS (Deploy Contínuo)

Sempre que você subir novas atualizações no Git:

### Opção 1: Script Automático (Recomendado)
```bash
cd /var/www/uaiflow
./update-app.sh
```
O script faz o `git pull`, recompila os containers (`docker compose up -d --build`), sincroniza as migrations e notifica o PostgREST.

### Opção 2: Manual
```bash
cd /var/www/uaiflow
git pull origin main
docker compose up -d --build
docker compose exec app node scripts/migrate.cjs
```

---

## Documentacao

- [Guia completo para novo proprietario](docs/GUIA_COMPLETO_NOVO_PROPRIETARIO.md)
- [Manual de uso](docs/MANUAL_DE_USO.md)
- [Instalacao tecnica](docs/INSTALLATION.md)
- [Supabase e migrations](docs/SUPABASE.md)
- [Meta e Instagram](docs/META_INSTAGRAM.md)
- [Vercel](docs/VERCEL.md)
- [Onboarding](docs/ONBOARDING.md)
- [Transferencia](docs/TRANSFER.md)
- [Checklist de release](docs/RELEASE_CHECKLIST.md)

## Segredos

Nunca envie ao GitHub `.env.local`, tokens do Instagram, `DATABASE_URL`, chaves secretas do Supabase, `INSTAGRAM_APP_SECRET` ou segredos de worker/sessao. Confira `npm run release:check` antes de publicar.

## Licenca

MIT. Consulte [LICENSE](LICENSE).