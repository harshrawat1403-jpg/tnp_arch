"use server";

import { redirect } from "next/navigation";

import { getPublicEnvironment } from "@/lib/environment";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { validateRegistrationInput } from "@/lib/student-profile/validation";

function registrationPath(state: "check-email" | "invalid" | "unavailable"): string {
  return `/register?state=${state}`;
}

export async function registerStudent(formData: FormData): Promise<void> {
  const input = validateRegistrationInput({
    displayName:
      typeof formData.get("displayName") === "string" ? String(formData.get("displayName")) : "",
    email: typeof formData.get("email") === "string" ? String(formData.get("email")) : "",
    password: typeof formData.get("password") === "string" ? String(formData.get("password")) : "",
  });

  if (!input.ok) {
    redirect(registrationPath("invalid"));
  }

  let supabase: Awaited<ReturnType<typeof createServerSupabaseClient>>;

  try {
    supabase = await createServerSupabaseClient();
  } catch {
    redirect(registrationPath("unavailable"));
  }

  const appUrl = getPublicEnvironment().appUrl?.toString() ?? "http://127.0.0.1:3000";
  const callbackUrl = new URL("/auth/callback", appUrl);
  callbackUrl.searchParams.set("next", "/student");

  const { error } = await supabase.auth.signUp({
    email: input.value.email,
    password: input.value.password,
    options: {
      data: { display_name: input.value.displayName },
      emailRedirectTo: callbackUrl.toString(),
    },
  });

  if (error) {
    redirect(registrationPath("invalid"));
  }

  redirect(registrationPath("check-email"));
}
