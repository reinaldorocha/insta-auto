# Deploy do UaiFlow na VPS com Docker (Nginx Proxy Manager + Supabase Self-Hosted)

Este guia foi elaborado para instalar o **UaiFlow** em uma VPS Linux que já possui **Docker**, **Nginx Proxy Manager** e **Supabase Self-Hosted** em execução.

---

## 1. Visão Geral da Arquitetura na sua VPS

Na sua VPS atual:
- **Nginx Proxy Manager (`root-app-1`)**: Está nas portas `80` e `443` gerenciando os certificados SSL e domínios.
- **Supabase Self-Hosted**:
  - `supabase-envoy` na porta `8800` (API Gateway para Auth, Rest e Storage).
  - `supabase-pooler` nas portas `54322` (modo sessão/direto) e `6543` (modo transação).
  - `supabase-db` (Postgres 17).
- **UaiFlow (Nova Aplicação)**:
  - Rodará no container `uaiflow-app` expondo a porta `3020` no host.
  - O container `uaiflow-cron` cuidará de chamar `/api/queue/drain` a cada 60 segundos para processar respostas automáticas e DMs do Instagram.
  - O Nginx Proxy Manager receberá o tráfego do seu domínio (ex: `https://insta.seudominio.com`) e repassará para a porta `3020`.

---

## 2. Preparando os Arquivos na VPS

Na sua VPS, escolha um diretório para o projeto (por exemplo `/root/uaiflow` ou `/home/projetos/uaiflow`):

```bash
mkdir -p /root/uaiflow
cd /root/uaiflow
```

Você pode clonar o seu repositório Git ou enviar os arquivos do projeto para lá:

```bash
git clone <URL_DO_SEU_REPOSITORIO> .
```

---

## 3. Instalação Automática via Script

Basta executar o instalador interativo:

```bash
bash install.sh
```

Ele detectará automaticamente suas credenciais do Supabase, gerará senhas seguras e criará o arquivo `.env`.

---

## 4. Configurar no Nginx Proxy Manager (NPM)

1. Acesse o painel do seu **Nginx Proxy Manager** (geralmente em `http://IP_DA_VPS:81`).
2. Vá em **Proxy Hosts** -> **Add Proxy Host**.
3. Na aba **Details**:
   - **Domain Names**: `insta.seudominio.com` (aponte o DNS tipo A desse subdomínio para o IP da sua VPS antes).
   - **Scheme**: `http`
   - **Forward Hostname / IP**: `172.17.0.1` (o gateway padrão do Docker para acessar a porta mapeada no host) ou o IP interno/público da sua VPS.
   - **Forward Port**: `3020`
   - Marque:
     - [x] **Block Common Exploits**
     - [x] **Websockets Support**
4. Na aba **SSL**:
   - Em **SSL Certificate**, selecione **Request a new SSL Certificate**.
   - Marque:
     - [x] **Force SSL**
     - [x] **HTTP/2 Support**
     - [x] **I Agree to the Let's Encrypt Terms of Service**
   - Informe seu e-mail.
5. Clique em **Save**.

---

## 5. Configurar o Supabase Auth

No seu painel do Supabase Studio:
1. Acesse **Authentication** -> **URL Configuration**.
2. Em **Site URL**, coloque:
   `https://insta.seudominio.com`
3. Em **Redirect URLs**, adicione:
   - `https://insta.seudominio.com/**`
   - `https://insta.seudominio.com/auth/callback`

---

## 6. Configurar o App na Meta for Developers

No painel do [Meta for Developers](https://developers.facebook.com):
1. No produto **Instagram**:
   - **OAuth Redirect URI**: `https://insta.seudominio.com/api/oauth/callback`
2. No produto **Webhooks**:
   - **Callback URL**: `https://insta.seudominio.com/api/webhook`
   - **Verify Token**: O mesmo valor que você colocou em `WEBHOOK_VERIFY_TOKEN` no `.env`.
   - Assine os campos de mensagens e comentários (`messages`, `messaging_postbacks`, `comments`, etc.).
3. Em **Configurações Básicas do App**:
   - **Política de Privacidade**: `https://insta.seudominio.com/privacidade`
   - **Exclusão de Dados**: `https://insta.seudominio.com/exclusao-de-dados`