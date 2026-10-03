"use server";

import { redirect } from "next/navigation";

import { validateRecruiterPassword } from "@/lib/auth/recruiter-password";
import { getCurrentIdentity } from "@/lib/supabase/current-identity";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export async function setRecruiterPassword(formData: FormData): Promise<void> {
  const identity = await getCurrentIdentity();
  if (!identity) redirect("/login?next=/recruiter/setup-password");
  if (identity.role !== "RECRUITER") redirect("/account?error=recruiter-access-required");

  const supabase = await createServerSupabaseClient();
  const { data: recruiter, error: recruiterError } = await supabase
    .from("recruiters")
    .select("id")
    .eq("user_id", identity.id)
    .maybeSingle();
  if (recruiterError || !recruiter) redirect("/account?error=recruiter-access-required");

  const password = formData.get("password");
  if (!validateRecruiterPassword(password, formData.get("confirmation"))) {
    redirect("/recruiter/setup-password?error=invalid");
  }

  const { error } = await supabase.auth.updateUser({ password: password as string });
  if (error) redirect("/recruiter/setup-password?error=provider");
  redirect("/recruiter");
}
