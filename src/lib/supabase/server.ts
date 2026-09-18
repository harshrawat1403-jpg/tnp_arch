import "server-only";

import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

import { getSupabaseEnvironment } from "./environment";

export async function createServerSupabaseClient() {
  const cookieStore = await cookies();
  const environment = getSupabaseEnvironment();

  return createServerClient(environment.url.toString(), environment.publishableKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options);
          });
        } catch {
          // Server Components cannot persist refresh cookies. src/proxy.ts performs that work.
        }
      },
    },
  });
}
