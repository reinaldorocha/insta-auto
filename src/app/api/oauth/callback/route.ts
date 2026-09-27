import { NextRequest, NextResponse } from "next/server";
import { getAppBaseUrl, getInstagramRedirectUri } from "@/lib/env";
import { saveInstagramConfig } from "@/lib/db/repositories";
import {
  exchangeCodeForLongToken,
  getInstagramProfile,
  subscribeWebhooks,
} from "@/lib/instagram/client";

export const runtime = "nodejs";

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  const error = request.nextUrl.searchParams.get("error_description") || request.nextUrl.searchParams.get("error");
  const appBaseUrl = getAppBaseUrl(request.url);
  const next = safeNextPath(request.nextUrl.searchParams.get("state"));

  if (error) {
    return NextResponse.redirect(`${appBaseUrl}${next}?instagram_error=${encodeURIComponent(error)}`);
  }

  if (!code) {
    return NextResponse.redirect(`${appBaseUrl}${next}?instagram_error=missing_code`);
  }

  try {
    const redirectUri = getInstagramRedirectUri(request);
    console.log("[oauth/callback] Trocando code por token com redirect_uri:", redirectUri);
    const token = await exchangeCodeForLongToken(code, redirectUri);
    const profile = await getInstagramProfile(token.access_token);
    const expiresAt = new Date(Date.now() + token.expires_in * 1000);

    let webhookSubscribedAt: Date | null = null;
    const userId = String(profile.user_id);

    try {
      await subscribeWebhooks(userId, token.access_token);
      webhookSubscribedAt = new Date();
    } catch (webhookError) {
      console.warn("[oauth] webhook subscription failed", webhookError instanceof Error ? webhookError.message : webhookError);
      webhookSubscribedAt = null;
    }

    await saveInstagramConfig({
      accessToken: token.access_token,
      userId,
      username: profile.username,
      name: profile.name ?? null,
      profilePictureUrl: profile.profile_picture_url ?? null,
      expiresAt,
      webhookSubscribedAt,
    });

    return NextResponse.redirect(`${appBaseUrl}${next}?instagram_connected=1`);
  } catch (callbackError) {
    const message = callbackError instanceof Error ? callbackError.message : "Erro desconhecido ao conectar Instagram";
    console.error("[oauth] Instagram callback failed", message);
    return NextResponse.redirect(`${appBaseUrl}${next}?instagram_error=${encodeURIComponent(message)}`);
  }
}

function safeNextPath(value: string | null) {
  return value?.startsWith("/") && !value.startsWith("//") ? value : "/perfis";
}