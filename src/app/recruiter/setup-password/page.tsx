import { redirect } from "next/navigation";

import { SubmitButton } from "@/components/forms/submit-button";
import { minimumRecruiterPasswordLength } from "@/lib/auth/recruiter-password";
import { getCurrentIdentity } from "@/lib/supabase/current-identity";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { setRecruiterPassword } from "./actions";

export const dynamic = "force-dynamic";

export default async function RecruiterPasswordPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string | string[] }>;
}) {
  const identity = await getCurrentIdentity();
  if (!identity) redirect("/login?next=/recruiter/setup-password");
  if (identity.role !== "RECRUITER") redirect("/account?error=recruiter-access-required");

  const supabase = await createServerSupabaseClient();
  const { data: recruiter, error } = await supabase
    .from("recruiters")
    .select("id")
    .eq("user_id", identity.id)
    .maybeSingle();
  if (error || !recruiter) redirect("/account?error=recruiter-access-required");

  const parameters = await searchParams;
  return (
    <section className="auth-panel" aria-labelledby="password-title">
      <p className="foundation__eyebrow">Recruiter access</p>
      <h1 id="password-title">Set your sign-in password.</h1>
      <p className="auth-panel__summary">
        Choose a password of at least {minimumRecruiterPasswordLength} characters to sign in with
        your invited email. You can return here from your recruiter workspace while signed in.
      </p>
      {parameters.error === "invalid" ? (
        <p className="auth-panel__message" role="alert">
          Enter matching passwords of at least {minimumRecruiterPasswordLength} characters.
        </p>
      ) : null}
      {parameters.error === "provider" ? (
        <p className="auth-panel__message" role="alert">
          The password could not be saved. Choose a stronger password and try again. If this
          continues, contact the TNP office.
        </p>
      ) : null}
      <form action={setRecruiterPassword} className="auth-form">
        <label htmlFor="password">New password</label>
        <input
          autoComplete="new-password"
          id="password"
          minLength={minimumRecruiterPasswordLength}
          name="password"
          required
          type="password"
        />
        <label htmlFor="confirmation">Confirm password</label>
        <input
          autoComplete="new-password"
          id="confirmation"
          minLength={minimumRecruiterPasswordLength}
          name="confirmation"
          required
          type="password"
        />
        <SubmitButton>Save password and continue</SubmitButton>
      </form>
    </section>
  );
}
