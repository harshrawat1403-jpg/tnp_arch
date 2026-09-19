import Link from "next/link";

import { SubmitButton } from "@/components/forms/submit-button";

import { registerStudent } from "./actions";

type RegistrationPageProps = {
  searchParams: Promise<{ state?: string | string[] }>;
};

function getState(value: string | string[] | undefined): string | undefined {
  return typeof value === "string" ? value : undefined;
}

export default async function RegistrationPage({ searchParams }: RegistrationPageProps) {
  const state = getState((await searchParams).state);

  return (
    <section className="auth-panel" aria-labelledby="registration-title">
      <p className="foundation__eyebrow">Student registration</p>
      <h1 id="registration-title">Create your student account.</h1>
      <p className="auth-panel__summary">
        Registration is available only to active students whose institutional email is already on
        the protected TNP roster. Administrative and recruiter accounts cannot be created here.
      </p>
      {state === "check-email" ? (
        <p className="auth-panel__message" role="status">
          Check your institutional email and confirm your account to continue.
        </p>
      ) : null}
      {state === "invalid" ? (
        <p className="auth-panel__message" role="alert">
          Registration could not be completed. Confirm your roster eligibility and try again.
        </p>
      ) : null}
      {state === "unavailable" ? (
        <p className="auth-panel__message" role="alert">
          Student registration is not configured in this environment.
        </p>
      ) : null}
      <form action={registerStudent} className="auth-form">
        <label htmlFor="displayName">Full name</label>
        <input autoComplete="name" id="displayName" name="displayName" required />
        <label htmlFor="email">Institutional email</label>
        <input autoComplete="email" id="email" name="email" required type="email" />
        <label htmlFor="password">Password</label>
        <input
          autoComplete="new-password"
          id="password"
          minLength={12}
          name="password"
          required
          type="password"
        />
        <p className="form-hint">
          Use at least 12 characters. You will confirm this email before signing in.
        </p>
        <SubmitButton pendingChildren="Creating account…">Create student account</SubmitButton>
      </form>
      <p className="auth-panel__secondary">
        Already registered? <Link href="/login">Sign in</Link>.
      </p>
    </section>
  );
}
