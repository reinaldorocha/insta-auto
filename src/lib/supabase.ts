import { createClient } from "@supabase/supabase-js";
import { requireEnv } from "@/lib/env";

export function createSupabaseAdminClient() {
  const supabaseUrl = process.env.SUPABASE_INTERNAL_URL || process.env.SUPABASE_URL || requireEnv("SUPABASE_URL");
  return createClient(supabaseUrl, requireEnv("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
    global: {
      headers: {
        Authorization: "",
      },
    },
  });
}
