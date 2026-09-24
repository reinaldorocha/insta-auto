import { cache } from "react";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { ensureUserWorkspace } from "@/lib/db/repositories";

export const getCurrentWorkspaceContext = cache(async function getCurrentWorkspaceContext() {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.getUser();

  if (error || !data.user?.email) {
    return null;
  }

  return ensureUserWorkspace({
    userId: data.user.id,
    email: data.user.email,
    fullName: getStringMetadata(data.user.user_metadata?.full_name) || getStringMetadata(data.user.user_metadata?.name),
    avatarUrl: getStringMetadata(data.user.user_metadata?.avatar_url) || getStringMetadata(data.user.user_metadata?.picture),
  });
});

function getStringMetadata(value: unknown) {
  return typeof value === "string" && value.trim() ? value : null;
}
