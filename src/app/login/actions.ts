"use server";

import { redirect } from "next/navigation";

import { getSafeAppPath } from "@/lib/auth/redirect";
import { createServerSupabaseClient } from "@/lib/supabase/server";

function loginPath(error: "invalid" | "unavailable", next: string): string {
  return `/login?error=${error}&next=${encodeURIComponent(next)}`;
}

export async function signIn(formData: FormData): Promise<void> {
  const nextValue = formData.get("next");
  const emailValue = formData.get("email");
  const passwordValue = formData.get("password");
  const next = getSafeAppPath(typeof nextValue === "string" ? nextValue : undefined);
  const email = typeof emailValue === "string" ? emailValue.trim() : "";
  const password = typeof passwordValue === "string" ? passwordValue : "";

  if (!email || !password) {
    redirect(loginPath("invalid", next));
  }

  let supabase: Awaited<ReturnType<typeof createServerSupabaseClient>>;

  try {
    supabase = await createServerSupabaseClient();
  } catch {
    redirect(loginPath("unavailable", next));
  }

  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    redirect(loginPath("invalid", next));
  }

  redirect(next);
}

export async function signOut(): Promise<void> {
  const supabase = await createServerSupabaseClient();
  await supabase.auth.signOut();
  redirect("/login?message=signed-out");
}
