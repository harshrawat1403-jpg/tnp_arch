import { getSafeAppPath } from "@/lib/auth/redirect";

import { signIn } from "./actions";

type LoginPageProps = {
  searchParams: Promise<{
    error?: string | string[];
    message?: string | string[];
    next?: string | string[];
  }>;
};

function getSingleSearchParameter(value: string | string[] | undefined): string | undefined {
  return typeof value === "string" ? value : undefined;
}

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const parameters = await searchParams;
  const next = getSafeAppPath(getSingleSearchParameter(parameters.next));
  const error = getSingleSearchParameter(parameters.error);
  const message = getSingleSearchParameter(parameters.message);

  return (
    <section className="auth-panel" aria-labelledby="login-title">
      <p className="foundation__eyebrow">Secure access</p>
      <h1 id="login-title">Sign in to the TNP portal.</h1>
      <p className="auth-panel__summary">
        Use an account provisioned through the approved institutional process. Public registration
        is not available.
      </p>
      {error === "invalid" ? (
        <p className="auth-panel__message" role="alert">
          Sign-in could not be completed. Check your credentials and try again.
        </p>
      ) : null}
      {error === "unavailable" ? (
        <p className="auth-panel__message" role="alert">
          Secure access is not configured in this environment.
        </p>
      ) : null}
      {message === "signed-out" ? (
        <p className="auth-panel__message">You have signed out.</p>
      ) : null}
      <form action={signIn} className="auth-form">
        <input name="next" type="hidden" value={next} />
        <label htmlFor="email">Institutional email</label>
        <input autoComplete="email" id="email" name="email" required type="email" />
        <label htmlFor="password">Password</label>
        <input
          autoComplete="current-password"
          id="password"
          name="password"
          required
          type="password"
        />
        <button className="button" type="submit">
          Sign in
        </button>
      </form>
    </section>
  );
}
