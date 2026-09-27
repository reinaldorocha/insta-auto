import {
  GRAPH_BASE_URL,
  IG_OAUTH_TOKEN_URL,
  META_API_VERSION,
  requireEnv,
} from "@/lib/env";

type GraphResponse<T> = T & { error?: { message: string; type?: string; code?: number } };

export type InstagramProfile = {
  user_id: string;
  username: string;
  name?: string;
  profile_picture_url?: string;
};

export async function exchangeCodeForLongToken(code: string, redirectUri: string) {
  const cleanCode = code.replace(/#_$/, "").replace(/#.*$/, "").trim();
  const clientId = requireEnv("INSTAGRAM_APP_ID");
  const clientSecret = requireEnv("INSTAGRAM_APP_SECRET");

  console.log(`[oauth] Requisitando shortToken com client_id=${clientId}, redirect_uri=${redirectUri}, code_len=${cleanCode.length}`);

  const shortTokenResponse = await fetch(IG_OAUTH_TOKEN_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: "authorization_code",
      redirect_uri: redirectUri,
      code: cleanCode,
    }),
  });

  const rawShortToken = await shortTokenResponse.text();
  let shortTokenPayload: Record<string, unknown> = {};
  try {
    shortTokenPayload = JSON.parse(rawShortToken);
  } catch {
    // raw text
  }

  if (!shortTokenResponse.ok || shortTokenPayload.error || shortTokenPayload.error_message) {
    const errorMsg =
      (shortTokenPayload.error_message as string) ||
      ((shortTokenPayload.error as { message?: string })?.message) ||
      (shortTokenPayload.error_description as string) ||
      rawShortToken ||
      `${shortTokenResponse.status} ${shortTokenResponse.statusText}`;
    console.error("[oauth] Falha ao obter shortToken:", shortTokenResponse.status, errorMsg);
    throw new Error(`Instagram OAuth Token (${shortTokenResponse.status}): ${errorMsg}`);
  }

  const shortToken = shortTokenPayload as { access_token: string; user_id: number };
  console.log(`[oauth] shortToken obtido com sucesso para user_id=${shortToken.user_id}. Tentando estender para token de 60 dias...`);

  // Tentar trocar por token de longa duracao (60 dias) via GET e POST
  const longTokenUrl = new URL("https://graph.instagram.com/access_token");
  longTokenUrl.searchParams.set("grant_type", "ig_exchange_token");
  longTokenUrl.searchParams.set("client_secret", clientSecret);
  longTokenUrl.searchParams.set("access_token", shortToken.access_token);

  try {
    // 1. Tentar GET (padrao documentado pela Meta)
    const longTokenResponse = await fetch(longTokenUrl);
    if (longTokenResponse.ok) {
      const longToken = await readGraphResponse<{ access_token: string; token_type: string; expires_in: number }>(longTokenResponse);
      console.log(`[oauth] Long-lived token obtido com sucesso! Validade: ${Math.round(longToken.expires_in / 86400)} dias.`);
      return longToken;
    }

    // 2. Se GET falhou, tentar POST
    console.warn(`[oauth] GET ig_exchange_token retornou ${longTokenResponse.status}. Tentando POST...`);
    const postResponse = await fetch("https://graph.instagram.com/access_token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "ig_exchange_token",
        client_secret: clientSecret,
        access_token: shortToken.access_token,
      }),
    });

    if (postResponse.ok) {
      const longToken = await readGraphResponse<{ access_token: string; token_type: string; expires_in: number }>(postResponse);
      console.log(`[oauth] Long-lived token obtido via POST com sucesso! Validade: ${Math.round(longToken.expires_in / 86400)} dias.`);
      return longToken;
    }

    const getErr = await longTokenResponse.text().catch(() => "");
    const postErr = await postResponse.text().catch(() => "");
    console.warn("[oauth] Falha ao estender token para 60 dias (GET:", getErr, "POST:", postErr, "). Usando shortToken temporario (1h) para nao impedir a conexao.");
  } catch (exchangeErr) {
    console.warn("[oauth] Erro inesperado ao tentar estender token:", exchangeErr instanceof Error ? exchangeErr.message : exchangeErr);
  }

  // Fallback seguro: usa o shortToken para permitir que a conta seja vinculada
  return {
    access_token: shortToken.access_token,
    token_type: "bearer",
    expires_in: 3600,
  };
}

export async function refreshLongLivedToken(accessToken: string) {
  const url = new URL(`${GRAPH_BASE_URL}/refresh_access_token`);
  url.searchParams.set("grant_type", "ig_refresh_token");
  url.searchParams.set("access_token", accessToken);

  const response = await fetch(url);
  return readGraphResponse<{ access_token: string; token_type: string; expires_in: number }>(response);
}

export async function getInstagramProfile(accessToken: string) {
  const url = new URL(`${GRAPH_BASE_URL}/me`);
  url.searchParams.set("fields", "user_id,username,name,profile_picture_url");
  url.searchParams.set("access_token", accessToken);

  const response = await fetch(url);
  return readGraphResponse<InstagramProfile>(response);
}

export type InstagramQuickReply = {
  title: string;
  payload: string;
};

export type InstagramButton = {
  type: "web_url" | "postback";
  title: string;
  url?: string | null;
  payload?: string | null;
};

export type InstagramUserProfile = {
  id: string;
  name?: string;
  username?: string;
  profile_pic?: string;
  follower_count?: number;
  is_user_follow_business?: boolean;
  is_business_follow_user?: boolean;
};

export async function getInstagramUserProfile(userId: string, accessToken: string) {
  const url = new URL(`${GRAPH_BASE_URL}/${userId}`);
  url.searchParams.set("fields", "name,username,profile_pic,follower_count,is_user_follow_business,is_business_follow_user");

  return graphFetch<InstagramUserProfile>(url, accessToken);
}

export async function subscribeWebhooks(instagramUserId: string, accessToken: string) {
  const url = new URL(`${GRAPH_BASE_URL}/${instagramUserId}/subscribed_apps`);
  url.searchParams.set("subscribed_fields", "comments,messages");

  const response = await graphFetch<{ success: boolean }>(url, accessToken, { method: "POST" });
  return response.success;
}


export async function getInstagramSubscribedApps(instagramUserId: string, accessToken: string) {
  const url = new URL(`${GRAPH_BASE_URL}/${instagramUserId}/subscribed_apps`);
  return graphFetch<{ data?: Array<Record<string, unknown>> }>(url, accessToken);
}
export async function listInstagramMedia(instagramUserId: string, accessToken: string) {
  const url = new URL(`${GRAPH_BASE_URL}/${instagramUserId}/media`);
  url.searchParams.set("fields", "id,media_type,media_url,thumbnail_url,caption,permalink");

  return graphFetch<{ data: unknown[] }>(url, accessToken);
}

export type MessengerProfileMenuItem = {
  title: string;
  type: "postback" | "web_url";
  payload?: string;
  url?: string;
};

export type MessengerProfileIceBreaker = {
  question: string;
  payload: string;
};

export async function setInstagramPersistentMenu(input: {
  instagramUserId: string;
  accessToken: string;
  items: MessengerProfileMenuItem[];
}) {
  const url = new URL(`${GRAPH_BASE_URL}/${input.instagramUserId}/messenger_profile`);

  return graphFetch<{ result?: string }>(url, input.accessToken, {
    method: "POST",
    body: JSON.stringify({
      platform: "instagram",
      persistent_menu: [
        {
          locale: "default",
          composer_input_disabled: false,
          call_to_actions: input.items.map((item) =>
            item.type === "web_url"
              ? { type: "web_url", title: item.title.slice(0, 30), url: item.url, webview_height_ratio: "full" }
              : { type: "postback", title: item.title.slice(0, 30), payload: item.payload },
          ),
        },
      ],
    }),
  });
}

export async function setInstagramIceBreakers(input: {
  instagramUserId: string;
  accessToken: string;
  items: MessengerProfileIceBreaker[];
}) {
  const url = new URL(`${GRAPH_BASE_URL}/${input.instagramUserId}/messenger_profile`);

  return graphFetch<{ result?: string }>(url, input.accessToken, {
    method: "POST",
    body: JSON.stringify({
      platform: "instagram",
      ice_breakers: [
        {
          locale: "default",
          call_to_actions: input.items.slice(0, 4).map((item) => ({
            question: item.question.slice(0, 80),
            payload: item.payload,
          })),
        },
      ],
    }),
  });
}


export async function getInstagramMessengerProfile(input: {
  instagramUserId: string;
  accessToken: string;
  fields: "persistent_menu" | "ice_breakers";
}) {
  const url = new URL(`${GRAPH_BASE_URL}/${input.instagramUserId}/messenger_profile`);
  url.searchParams.set("fields", input.fields);

  return graphFetch<{ data?: Array<Record<string, unknown>> }>(url, input.accessToken);
}

export async function deleteInstagramMessengerProfile(input: {
  instagramUserId: string;
  accessToken: string;
  fields: "persistent_menu" | "ice_breakers";
}) {
  const url = new URL(`${GRAPH_BASE_URL}/${input.instagramUserId}/messenger_profile`);
  url.searchParams.set("fields", JSON.stringify([input.fields]));

  return graphFetch<{ result?: string }>(url, input.accessToken, { method: "DELETE" });
}

export type InstagramPublishType = "feed_image" | "reel_video" | "story_image" | "story_video";

export type InstagramCarouselMediaItem = {
  type: "image" | "video";
  url: string;
  coverUrl?: string | null;
};

export async function createInstagramMediaContainer(input: {
  instagramUserId: string;
  accessToken: string;
  publishType: InstagramPublishType;
  mediaUrl: string;
  caption?: string;
  coverUrl?: string | null;
}) {
  const url = new URL(`${GRAPH_BASE_URL}/${input.instagramUserId}/media`);
  const body: Record<string, unknown> = {
    caption: input.caption || "",
  };

  if (input.publishType === "reel_video") {
    body.media_type = "REELS";
    body.video_url = input.mediaUrl;
    body.share_to_feed = true;
    if (input.coverUrl) body.cover_url = input.coverUrl;
  } else if (input.publishType === "story_video") {
    body.media_type = "STORIES";
    body.video_url = input.mediaUrl;
  } else if (input.publishType === "story_image") {
    body.media_type = "STORIES";
    body.image_url = input.mediaUrl;
  } else {
    body.image_url = input.mediaUrl;
  }

  return graphFetch<{ id: string }>(url, input.accessToken, {
    method: "POST",
    body: JSON.stringify(body),
  });
}
export async function createInstagramCarouselItemContainer(input: {
  instagramUserId: string;
  accessToken: string;
  item: InstagramCarouselMediaItem;
}) {
  const url = new URL(`${GRAPH_BASE_URL}/${input.instagramUserId}/media`);
  const body: Record<string, unknown> = {
    is_carousel_item: true,
  };

  if (input.item.type === "video") {
    body.media_type = "VIDEO";
    body.video_url = input.item.url;
    if (input.item.coverUrl) body.cover_url = input.item.coverUrl;
  } else {
    body.image_url = input.item.url;
  }

  return graphFetch<{ id: string }>(url, input.accessToken, {
    method: "POST",
    body: JSON.stringify(body),
  });
}

export async function createInstagramCarouselContainer(input: {
  instagramUserId: string;
  accessToken: string;
  children: string[];
  caption?: string;
}) {
  const url = new URL(`${GRAPH_BASE_URL}/${input.instagramUserId}/media`);

  return graphFetch<{ id: string }>(url, input.accessToken, {
    method: "POST",
    body: JSON.stringify({
      media_type: "CAROUSEL",
      children: input.children.join(","),
      caption: input.caption || "",
    }),
  });
}

export async function getInstagramMediaContainerStatus(containerId: string, accessToken: string) {
  const url = new URL(`${GRAPH_BASE_URL}/${containerId}`);
  url.searchParams.set("fields", "id,status_code,status");
  return graphFetch<{ id: string; status_code?: string; status?: string }>(url, accessToken);
}

export async function publishInstagramMediaContainer(input: {
  instagramUserId: string;
  accessToken: string;
  containerId: string;
}) {
  const url = new URL(`${GRAPH_BASE_URL}/${input.instagramUserId}/media_publish`);
  return graphFetch<{ id: string }>(url, input.accessToken, {
    method: "POST",
    body: JSON.stringify({ creation_id: input.containerId }),
  });
}

export async function getPublishedInstagramMedia(mediaId: string, accessToken: string) {
  const url = new URL(`${GRAPH_BASE_URL}/${mediaId}`);
  url.searchParams.set("fields", "id,permalink,media_type,timestamp");
  return graphFetch<{ id: string; permalink?: string }>(url, accessToken);
}
export async function sendPrivateReply(input: {
  instagramUserId: string;
  commentId: string;
  accessToken: string;
  text: string;
  quickReplyLabel?: string | null;
  quickReplyPayload?: string | null;
  quickReplies?: InstagramQuickReply[] | null;
  buttonLabel?: string | null;
  url?: string | null;
  buttonPayload?: string | null;
  buttons?: InstagramButton[] | null;
}) {
  return sendMessage({
    instagramUserId: input.instagramUserId,
    accessToken: input.accessToken,
    recipient: { comment_id: input.commentId },
    message: input.buttons?.length
      ? buildButtonsMessage(input.text, input.buttons)
      : input.url
        ? buildButtonMessage(input.text, input.buttonLabel || "Abrir link", input.url)
        : input.buttonPayload
          ? buildButtonMessage(input.text, input.buttonLabel || "Continuar", null, input.buttonPayload)
          : buildTextMessage(input.text, input.quickReplyLabel, input.quickReplyPayload, input.quickReplies),
  });
}

export async function sendDirectMessage(input: {
  instagramUserId: string;
  recipientId: string;
  accessToken: string;
  text: string;
  buttonLabel?: string | null;
  url?: string | null;
  buttonPayload?: string | null;
  quickReplyLabel?: string | null;
  quickReplyPayload?: string | null;
  quickReplies?: InstagramQuickReply[] | null;
  buttons?: InstagramButton[] | null;
}) {
  return sendMessage({
    instagramUserId: input.instagramUserId,
    accessToken: input.accessToken,
    recipient: { id: input.recipientId },
    message: input.buttons?.length
      ? buildButtonsMessage(input.text, input.buttons)
      : input.url
        ? buildButtonMessage(input.text, input.buttonLabel || "Abrir link", input.url)
        : input.buttonPayload
          ? buildButtonMessage(input.text, input.buttonLabel || "Continuar", null, input.buttonPayload)
          : buildTextMessage(input.text, input.quickReplyLabel, input.quickReplyPayload, input.quickReplies),
  });
}

export async function sendDirectMediaMessage(input: {
  instagramUserId: string;
  recipientId: string;
  accessToken: string;
  mediaType: "image" | "audio" | "video";
  url: string;
}) {
  return sendMessage({
    instagramUserId: input.instagramUserId,
    accessToken: input.accessToken,
    recipient: { id: input.recipientId },
    message: buildMediaMessage(input.mediaType, input.url),
  });
}

export async function sendPublicCommentReply(input: {
  commentId: string;
  accessToken: string;
  text: string;
}) {
  const url = new URL(`${GRAPH_BASE_URL}/${input.commentId}/replies`);
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${input.accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ message: input.text }),
  });

  return readGraphResponse<{ id: string }>(response);
}

function sendMessage(input: {
  instagramUserId: string;
  accessToken: string;
  recipient: Record<string, string>;
  message: Record<string, unknown>;
}) {
  const url = new URL(`${GRAPH_BASE_URL}/${input.instagramUserId}/messages`);

  return graphFetch<{ recipient_id?: string; message_id?: string }>(url, input.accessToken, {
    method: "POST",
    body: JSON.stringify({ recipient: input.recipient, message: input.message }),
  });
}

function buildTextMessage(text: string, quickReplyLabel?: string | null, quickReplyPayload?: string | null, quickReplies?: InstagramQuickReply[] | null) {
  const message: Record<string, unknown> = { text };

  const replies = quickReplies?.length
    ? quickReplies
    : quickReplyLabel && quickReplyPayload
      ? [{ title: quickReplyLabel, payload: quickReplyPayload }]
      : [];

  if (replies.length) {
    message.quick_replies = replies.slice(0, 13).map((reply) => ({
      content_type: "text",
      title: reply.title.slice(0, 20),
      payload: reply.payload,
    }));
  }

  return message;
}

function buildButtonMessage(text: string, buttonLabel: string, url: string | null, payload?: string | null) {
  return buildButtonsMessage(text, [
    url
      ? { type: "web_url", url, title: buttonLabel }
      : { type: "postback", payload: payload || buttonLabel, title: buttonLabel },
  ]);
}

function buildButtonsMessage(text: string, buttons: InstagramButton[]) {
  return {
    attachment: {
      type: "template",
      payload: {
        template_type: "button",
        text,
        buttons: buttons.slice(0, 3).map((button) => button.type === "web_url"
          ? {
              type: "web_url",
              url: button.url,
              title: button.title.slice(0, 20),
            }
          : {
              type: "postback",
              payload: button.payload || button.title,
              title: button.title.slice(0, 20),
            }),
      },
    },
  };
}

function buildMediaMessage(type: "image" | "audio" | "video", url: string) {
  return {
    attachment: {
      type,
      payload: { url },
    },
  };
}

async function graphFetch<T>(url: URL, accessToken: string, init: RequestInit = {}) {
  const response = await fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      ...init.headers,
    },
  });

  return readGraphResponse<T>(response);
}

async function readGraphResponse<T>(response: Response): Promise<T> {
  const rawText = await response.text();
  let payload: Record<string, unknown> = {};
  try {
    payload = JSON.parse(rawText);
  } catch {
    // not JSON
  }

  const errObj = payload.error as Record<string, unknown> | string | undefined;
  const errMsg =
    (typeof errObj === "string" ? errObj : (errObj?.message as string)) ||
    (payload.error_description as string) ||
    (payload.error_message as string) ||
    (payload.message as string) ||
    rawText ||
    `${response.status} ${response.statusText}`;

  if (!response.ok || payload.error || payload.error_message) {
    console.error(`[oauth] Instagram Graph Error (${response.status}):`, errMsg);
    throw new Error(`Instagram Graph ${META_API_VERSION}: ${errMsg}`);
  }

  return payload as T;
}
