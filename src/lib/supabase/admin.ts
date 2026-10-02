import "server-only";

import { createClient } from "@supabase/supabase-js";

import { getSupabaseAdminEnvironment } from "./environment";

/**
 * This client is intentionally limited to the recruiter invitation hand-off.
 * All product authorization remains in the actor-bound database procedures.
 */
export function createSupabaseInvitationAdminClient() {
  const environment = getSupabaseAdminEnvironment();

  return createClient(environment.url.toString(), environment.secretKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  });
}
