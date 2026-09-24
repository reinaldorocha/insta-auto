import type {
  Automation,
  AutomationTrigger,
  DelayMode,
  FlowEdgeDefinition,
  FlowNodeDefinition,
  MatchType,
  QuickReply,
  ReplyMode,
} from "./db/repositories";

export type FlowExportPackage = {
  schema: "uaiflow/v1";
  version: 1;
  exported_at: string;
  automation: {
    name: string;
    active?: boolean;
    triggers: AutomationTrigger[];
    keywords: string[];
    match_type: MatchType;
    post_id: string | null;
    public_replies: string[];
    public_reply_mode: ReplyMode;
    welcome_dm: string;
    quick_reply_label: string;
    quick_replies: QuickReply[];
    link_text: string;
    link_button_label: string;
    link_url: string;
    reply_delay_seconds: number;
    reply_delay_mode: DelayMode;
    reply_delay_min_seconds: number;
    reply_delay_max_seconds: number;
    reminder_text: string;
    reminder_delay_minutes: number;
    reminder_delay_seconds: number;
    reminder_delay_mode: DelayMode;
    reminder_delay_min_seconds: number;
    reminder_delay_max_seconds: number;
    require_follower: boolean;
    non_follower_dm: string;
    non_follower_button_label: string;
    follower_confirmation_text: string;
    follower_confirmation_greetings: string[];
    flow_nodes?: FlowNodeDefinition[];
    flow_edges?: FlowEdgeDefinition[];
  };
};

export function exportFlowToPackage(
  data: Partial<Automation> & { name?: string },
): FlowExportPackage {
  return {
    schema: "uaiflow/v1",
    version: 1,
    exported_at: new Date().toISOString(),
    automation: {
      name: data.name || "Novo Fluxo",
      active: data.active ?? true,
      triggers: data.triggers?.length ? data.triggers : ["comments"],
      keywords: data.keywords ?? [],
      match_type: data.match_type ?? "contains",
      post_id: data.post_id ?? null,
      public_replies: data.public_replies ?? [],
      public_reply_mode: data.public_reply_mode ?? "random",
      welcome_dm: data.welcome_dm ?? "Oi! Toque no botao abaixo para receber o link.",
      quick_reply_label: data.quick_reply_label ?? "Quero receber",
      quick_replies: data.quick_replies ?? [],
      link_text: data.link_text ?? "Aqui esta o link que voce pediu:",
      link_button_label: data.link_button_label ?? "Abrir link",
      link_url: data.link_url ?? "",
      reply_delay_seconds: data.reply_delay_seconds ?? 0,
      reply_delay_mode: data.reply_delay_mode ?? "fixed",
      reply_delay_min_seconds: data.reply_delay_min_seconds ?? 0,
      reply_delay_max_seconds: data.reply_delay_max_seconds ?? 0,
      reminder_text: data.reminder_text ?? "",
      reminder_delay_minutes: data.reminder_delay_minutes ?? 1440,
      reminder_delay_seconds: data.reminder_delay_seconds ?? 86400,
      reminder_delay_mode: data.reminder_delay_mode ?? "fixed",
      reminder_delay_min_seconds: data.reminder_delay_min_seconds ?? 86400,
      reminder_delay_max_seconds: data.reminder_delay_max_seconds ?? 86400,
      require_follower: Boolean(data.require_follower),
      non_follower_dm: data.non_follower_dm ?? "Primeiro precisa me seguir para receber o acesso, depois que me seguir digite novamente a palavra que enviou acima.",
      non_follower_button_label: data.non_follower_button_label ?? "Seguir no Insta",
      follower_confirmation_text: data.follower_confirmation_text ?? "Digite Eu Quero aqui em baixo para liberar.",
      follower_confirmation_greetings: data.follower_confirmation_greetings ?? ["Oii", "Ola", "Eii", "Eae", "Opa"],
      flow_nodes: data.flow_nodes ?? [],
      flow_edges: data.flow_edges ?? [],
    },
  };
}

export function downloadFlowJsonFile(pkg: FlowExportPackage, customName?: string) {
  const filename = `${slugify(customName || pkg.automation.name || "fluxo")}-flow.json`;
  const jsonString = JSON.stringify(pkg, null, 2);
  const blob = new Blob([jsonString], { type: "application/json;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

export function parseAndValidateFlowJson(
  rawContent: string,
): { ok: true; data: FlowExportPackage["automation"] } | { ok: false; error: string } {
  try {
    const parsed = JSON.parse(rawContent) as Record<string, unknown>;
    if (!parsed || typeof parsed !== "object") {
      return { ok: false, error: "Arquivo JSON invalido ou vazio." };
    }

    const auto = (
      parsed.schema && typeof parsed.automation === "object" && parsed.automation
        ? parsed.automation
        : parsed
    ) as Record<string, unknown>;

    const name = typeof auto.name === "string" && auto.name.trim() ? auto.name.trim() : "Fluxo Importado";

    const triggers = Array.isArray(auto.triggers)
      ? (auto.triggers.filter((t) => ["comments", "story", "dm"].includes(String(t))) as AutomationTrigger[])
      : (["comments"] as AutomationTrigger[]);

    const keywords = Array.isArray(auto.keywords) ? auto.keywords.map(String).filter(Boolean) : [];

    const match_type: MatchType =
      auto.match_type === "exact" || auto.match_type === "any" ? auto.match_type : "contains";

    const post_id = typeof auto.post_id === "string" && auto.post_id.trim() ? auto.post_id.trim() : null;

    const public_replies = Array.isArray(auto.public_replies)
      ? auto.public_replies.map(String).filter(Boolean)
      : [];

    const public_reply_mode: ReplyMode =
      auto.public_reply_mode === "fixed" ? "fixed" : "random";

    const welcome_dm = typeof auto.welcome_dm === "string" ? auto.welcome_dm : "";
    const quick_reply_label = typeof auto.quick_reply_label === "string" ? auto.quick_reply_label : "Quero receber";

    const quick_replies = Array.isArray(auto.quick_replies)
      ? (auto.quick_replies as QuickReply[])
          .filter((q) => q && typeof q === "object" && q.title && q.payload)
          .map((q) => ({ title: String(q.title).trim(), payload: String(q.payload).trim() }))
      : [];

    const link_text = typeof auto.link_text === "string" ? auto.link_text : "";
    const link_button_label = typeof auto.link_button_label === "string" ? auto.link_button_label : "";
    const link_url = typeof auto.link_url === "string" ? auto.link_url : "";

    const flow_nodes = Array.isArray(auto.flow_nodes) ? (auto.flow_nodes as FlowNodeDefinition[]) : [];
    const flow_edges = Array.isArray(auto.flow_edges) ? (auto.flow_edges as FlowEdgeDefinition[]) : [];

    return {
      ok: true,
      data: {
        name,
        active: auto.active !== false,
        triggers: triggers.length ? triggers : ["comments"],
        keywords,
        match_type,
        post_id,
        public_replies,
        public_reply_mode,
        welcome_dm,
        quick_reply_label,
        quick_replies,
        link_text,
        link_button_label,
        link_url,
        reply_delay_seconds: Number(auto.reply_delay_seconds || 0),
        reply_delay_mode: auto.reply_delay_mode === "random" ? "random" : "fixed",
        reply_delay_min_seconds: Number(auto.reply_delay_min_seconds || 0),
        reply_delay_max_seconds: Number(auto.reply_delay_max_seconds || 0),
        reminder_text: typeof auto.reminder_text === "string" ? auto.reminder_text : "",
        reminder_delay_minutes: Number(auto.reminder_delay_minutes || 1440),
        reminder_delay_seconds: Number(auto.reminder_delay_seconds || 86400),
        reminder_delay_mode: auto.reminder_delay_mode === "random" ? "random" : "fixed",
        reminder_delay_min_seconds: Number(auto.reminder_delay_min_seconds || 86400),
        reminder_delay_max_seconds: Number(auto.reminder_delay_max_seconds || 86400),
        require_follower: auto.require_follower === true,
        non_follower_dm: typeof auto.non_follower_dm === "string" ? auto.non_follower_dm : "",
        non_follower_button_label: typeof auto.non_follower_button_label === "string" ? auto.non_follower_button_label : "Seguir no Insta",
        follower_confirmation_text: typeof auto.follower_confirmation_text === "string" ? auto.follower_confirmation_text : "",
        follower_confirmation_greetings: Array.isArray(auto.follower_confirmation_greetings)
          ? auto.follower_confirmation_greetings.map(String).filter(Boolean)
          : ["Oii", "Ola", "Eii", "Eae", "Opa"],
        flow_nodes,
        flow_edges,
      },
    };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : "Erro ao ler JSON." };
  }
}

function slugify(text: string): string {
  return text
    .toString()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)+/g, "")
    .slice(0, 50) || "fluxo";
}
