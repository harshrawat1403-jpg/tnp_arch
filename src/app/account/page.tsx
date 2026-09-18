import { redirect } from "next/navigation";

import { signOut } from "@/app/login/actions";
import { getCurrentIdentity } from "@/lib/supabase/current-identity";

export const dynamic = "force-dynamic";

export default async function AccountPage() {
  const identity = await getCurrentIdentity();

  if (!identity) {
    redirect("/login?error=invalid&next=/account");
  }

  return (
    <section className="auth-panel" aria-labelledby="account-title">
      <p className="foundation__eyebrow">Authenticated session</p>
      <h1 id="account-title">Account access confirmed.</h1>
      <p className="auth-panel__summary">
        Signed in as {identity.displayName}. Your protected platform role is {identity.role}.
      </p>
      <p className="foundation__note">
        Product workspaces are introduced only in their approved later phases.
      </p>
      <form action={signOut}>
        <button className="text-link" type="submit">
          Sign out
        </button>
      </form>
    </section>
  );
}
