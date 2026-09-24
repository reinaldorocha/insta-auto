import {
  claimQueueJobs,
  getConfig,
  getTemplateContext,
  markExpiredDmsSkipped,
  markJobFailed,
  markJobSent,
  recoverStuckSendingJobs,
  sentDmCountLastHour,
  type QueueJob,
} from "@/lib/db/repositories";
import {
  sendDirectMediaMessage,
  sendDirectMessage,
  sendPrivateReply,
  sendPublicCommentReply,
} from "@/lib/instagram/client";
import { renderMessageTemplate } from "@/lib/message-template";

const MAX_JOBS_PER_DRAIN = 40;
const MAX_AUTOMATED_DMS_PER_HOUR = 200;
const SEND_DELAY_MS = 500;

export async function drainQueue(limit = MAX_JOBS_PER_DRAIN) {
  const recovered = await recoverStuckSendingJobs();
  if (recovered > 0) {
    console.log(`[Queue] ${recovered} mensagem(ns) presa(s) em 'sending' recuperada(s).`);
  }

  await markExpiredDmsSkipped();

  const jobs = await claimQueueJobs(Math.min(limit, MAX_JOBS_PER_DRAIN));
  let sent = 0;
  let failed = 0;

  for (const job of jobs) {
    const config = await getConfig(job.account_id);
    if (!config.instagram_access_token || !config.instagram_user_id) {
      await markJobFailed(job.id, "Instagram nao conectado para este perfil");
      failed += 1;
      continue;
    }

    const countsTowardDmLimit = job.send_type === "dm" || job.send_type === "private_reply";
    const hourlyCount = countsTowardDmLimit ? await sentDmCountLastHour(config.account_id) : 0;
    if (hourlyCount >= MAX_AUTOMATED_DMS_PER_HOUR) {
      await markJobFailed(job.id, "Limite horario de seguranca atingido para este perfil");
      failed += 1;
      continue;
    }

    try {
      await sendJob(job, config.instagram_user_id, config.instagram_access_token);
      await markJobSent(job.id);
      sent += 1;
    } catch (error) {
      failed += 1;
      await markJobFailed(job.id, error instanceof Error ? error.message : "Erro desconhecido ao enviar");
    }

    await delay(SEND_DELAY_MS);
  }

  return { processed: jobs.length, sent, failed, recovered };
}
async function sendJob(job: QueueJob, instagramUserId: string, accessToken: string) {
  const context = await getTemplateContext({ contactId: job.contact_id, automationId: job.automation_id });
  const text = renderMessageTemplate(String(job.payload.text || ""), context);
  const buttonLabel = renderOptionalString(job.payload.buttonLabel, context);
  const url = renderOptionalString(job.payload.url, context);
  const buttonPayload = renderOptionalString(job.payload.buttonPayload, context);
  const quickReplyLabel = renderOptionalString(job.payload.quickReplyLabel, context);
  const quickReplyPayload = optionalString(job.payload.quickReplyPayload);
  const quickReplies = renderQuickReplies(job.payload.quickReplies, context);
  const mediaUrl = renderOptionalString(job.payload.mediaUrl, context);
  const mediaType = normalizeMediaType(job.payload.mediaType);
  const buttons = renderButtons(job.payload.buttons, context);

  if (job.send_type === "private_reply") {
    if (!job.instagram_comment_id) throw new Error("Missing comment id for private reply");
    await sendPrivateReply({
      instagramUserId,
      commentId: job.instagram_comment_id,
      accessToken,
      text,
      quickReplyLabel,
      quickReplyPayload,
      quickReplies,
      buttonLabel,
      url,
      buttonPayload,
      buttons,
    });
    return;
  }

  if (job.send_type === "public_reply") {
    if (!job.instagram_comment_id) throw new Error("Missing comment id for public reply");
    await sendPublicCommentReply({ commentId: job.instagram_comment_id, accessToken, text });
    return;
  }

  if (!job.instagram_recipient_id) throw new Error("Missing recipient id for DM");

  if (job.payload.type === "media") {
    if (!mediaUrl) throw new Error("Missing media URL for DM");
    if (text) {
      await sendDirectMessage({ instagramUserId, recipientId: job.instagram_recipient_id, accessToken, text });
    }
    await sendDirectMediaMessage({
      instagramUserId,
      recipientId: job.instagram_recipient_id,
      accessToken,
      mediaType,
      url: mediaUrl,
    });
    return;
  }

  await sendDirectMessage({
    instagramUserId,
    recipientId: job.instagram_recipient_id,
    accessToken,
    text,
    buttonLabel,
    url,
    buttonPayload,
    quickReplyLabel,
    quickReplyPayload,
    quickReplies,
    buttons,
  });
}

function renderOptionalString(value: unknown, context: Record<string, string>) {
  const text = optionalString(value);
  return text ? renderMessageTemplate(text, context) : null;
}

function renderButtons(value: unknown, context: Record<string, string>) {
  if (!Array.isArray(value)) return null;

  const buttons = value
    .map((item) => typeof item === "object" && item ? item as Record<string, unknown> : null)
    .filter(Boolean)
    .map((item) => ({
      type: item?.type === "postback" ? "postback" as const : "web_url" as const,
      title: renderMessageTemplate(String(item?.title || ""), context).trim(),
      url: renderOptionalString(item?.url, context),
      payload: renderOptionalString(item?.payload, context),
    }))
    .filter((item) => item.title && ((item.type === "web_url" && item.url) || (item.type === "postback" && item.payload)));

  return buttons.length ? buttons : null;
}

function renderQuickReplies(value: unknown, context: Record<string, string>) {
  if (!Array.isArray(value)) return null;

  const replies = value
    .map((item) => typeof item === "object" && item ? item as Record<string, unknown> : null)
    .filter(Boolean)
    .map((item) => ({
      title: renderMessageTemplate(String(item?.title || ""), context).trim(),
      payload: renderMessageTemplate(String(item?.payload || ""), context).trim(),
    }))
    .filter((item) => item.title && item.payload);

  return replies.length ? replies : null;
}

function optionalString(value: unknown) {
  return typeof value === "string" && value.trim() ? value : null;
}

function normalizeMediaType(value: unknown): "image" | "audio" | "video" {
  if (value === "audio") return "audio";
  if (value === "video") return "video";
  return "image";
}

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
