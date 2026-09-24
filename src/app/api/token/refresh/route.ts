import { NextRequest, NextResponse } from "next/server";
import {
  getConfig,
  getInstagramAccountById,
  listAccountsNeedingTokenRefresh,
  listInstagramAccounts,
  updateToken,
} from "@/lib/db/repositories";
import { refreshLongLivedToken } from "@/lib/instagram/client";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const runtime = "nodejs";

export async function GET(request: NextRequest) {
  return handleRefresh(request);
}

export async function POST(request: NextRequest) {
  return handleRefresh(request);
}

async function isAuthorized(request: NextRequest): Promise<boolean> {
  const providedSecret = request.headers.get("x-worker-secret") || request.nextUrl.searchParams.get("secret");

  if (process.env.WORKER_SECRET && providedSecret === process.env.WORKER_SECRET) {
    return true;
  }

  if (!process.env.WORKER_SECRET) {
    return true;
  }

  try {
    const supabase = await createSupabaseServerClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (user) return true;
  } catch {
    // ignore
  }

  return false;
}

async function handleRefresh(request: NextRequest) {
  if (!(await isAuthorized(request))) {
    return NextResponse.json({ error: "Nao autorizado" }, { status: 401 });
  }

  const redirectUrl = request.nextUrl.searchParams.get("redirect");
  const isBrowser =
    Boolean(redirectUrl) || (request.headers.get("accept") || "").includes("text/html");

  const force = request.nextUrl.searchParams.get("force") === "1" || request.nextUrl.searchParams.get("force") === "true";
  const targetAccountId = request.nextUrl.searchParams.get("accountId");

  type AccountTarget = {
    id: string | null;
    instagram_username: string;
    instagram_access_token: string;
    token_expires_at: string | null;
  };

  let accounts: AccountTarget[] = [];

  if (targetAccountId) {
    const account = await getInstagramAccountById(targetAccountId);
    if (!account || !account.instagram_access_token) {
      if (isBrowser && redirectUrl) {
        return NextResponse.redirect(new URL(`${redirectUrl}?error=Conta_nao_encontrada`, request.url));
      }
      return NextResponse.json({ ok: false, error: "Conta nao encontrada ou sem token" }, { status: 404 });
    }
    accounts = [
      {
        id: account.id,
        instagram_username: account.instagram_username || "instagram",
        instagram_access_token: account.instagram_access_token,
        token_expires_at: account.token_expires_at,
      },
    ];
  } else if (force) {
    const allAccounts = await listInstagramAccounts();
    const valid = allAccounts.filter((a) => Boolean(a.instagram_access_token));
    if (valid.length > 0) {
      accounts = valid.map((a) => ({
        id: a.id,
        instagram_username: a.instagram_username || "instagram",
        instagram_access_token: a.instagram_access_token!,
        token_expires_at: a.token_expires_at,
      }));
    } else {
      const config = await getConfig();
      if (config.instagram_access_token) {
        accounts = [
          {
            id: null,
            instagram_username: config.instagram_username || "default",
            instagram_access_token: config.instagram_access_token,
            token_expires_at: config.token_expires_at,
          },
        ];
      }
    }
  } else {
    accounts = await listAccountsNeedingTokenRefresh();
  }

  if (accounts.length === 0) {
    if (isBrowser && redirectUrl) {
      return NextResponse.redirect(new URL(`${redirectUrl}?refreshed=0&msg=Tokens_em_dia`, request.url));
    }
    return NextResponse.json({
      ok: true,
      message: "Nenhum token precisa de renovacao no momento",
      refreshed: 0,
      results: [],
    });
  }

  const results: Array<{
    id: string | null;
    username: string;
    status: "refreshed" | "failed" | "skipped";
    expiresAt?: string;
    error?: string;
  }> = [];

  for (const account of accounts) {
    try {
      const token = await refreshLongLivedToken(account.instagram_access_token);
      const expiresAt = new Date(Date.now() + token.expires_in * 1000);

      await updateToken({
        accountId: account.id,
        accessToken: token.access_token,
        expiresAt,
      });

      console.log(`[TokenRefresh] Token Meta renovado com sucesso para @${account.instagram_username} (expira em ${expiresAt.toISOString()})`);
      results.push({
        id: account.id,
        username: account.instagram_username,
        status: "refreshed",
        expiresAt: expiresAt.toISOString(),
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Erro desconhecido ao renovar token";
      console.error(`[TokenRefresh] Falha ao renovar token da conta @${account.instagram_username}:`, message);

      const isTooEarly = message.includes("less than 24 hours old");
      results.push({
        id: account.id,
        username: account.instagram_username,
        status: isTooEarly ? "skipped" : "failed",
        error: isTooEarly ? "Token emitido/renovado ha menos de 24h (limite da Meta)" : message,
      });
    }
  }

  const refreshedCount = results.filter((r) => r.status === "refreshed").length;

  if (isBrowser && redirectUrl) {
    const param = refreshedCount > 0 ? `refreshed=${refreshedCount}` : `error=${encodeURIComponent(results[0]?.error || "Falha_ao_renovar")}`;
    return NextResponse.redirect(new URL(`${redirectUrl}?${param}`, request.url));
  }

  return NextResponse.json({
    ok: true,
    refreshed: refreshedCount,
    total: accounts.length,
    results,
  });
}
