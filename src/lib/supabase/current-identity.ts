import "server-only";

import { resolveAuthenticatedIdentity, type AuthenticatedIdentity } from "@/lib/auth/role";

import { createServerSupabaseClient } from "./server";

export async function getCurrentIdentity(): Promise<AuthenticatedIdentity | null> {
  const supabase = await createServerSupabaseClient();
  const { data: claimsData, error: claimsError } = await supabase.auth.getClaims();
  const authenticatedUserId = claimsData?.claims?.sub;

  if (claimsError || typeof authenticatedUserId !== "string") {
    return null;
  }

  const { data, error } = await supabase
    .from("profiles")
    .select("id, display_name, role, is_active")
    .eq("id", authenticatedUserId)
    .maybeSingle();

  if (error) {
    throw new Error("Unable to resolve the authenticated account.");
  }

  return resolveAuthenticatedIdentity(data, authenticatedUserId);
}
