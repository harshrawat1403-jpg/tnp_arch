import { redirect } from "next/navigation";
import Link from "next/link";

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
        Your protected role determines the operational workspace available to you.
      </p>
      {identity.role === "RECRUITER" ? (
        <Link className="text-link" href="/recruiter">
          Open recruiter workspace
        </Link>
      ) : null}
      {identity.role === "STUDENT" ? (
        <Link className="text-link" href="/student/drives">
          View published drives
        </Link>
      ) : null}
      {["SUPER_ADMIN", "TNP_SECRETARY", "TNP_COORDINATOR"].includes(identity.role) ? (
        <Link className="text-link" href="/tnp/drives">
          Manage drives and eligibility
        </Link>
      ) : null}
      {["SUPER_ADMIN", "TNP_SECRETARY", "TNP_COORDINATOR"].includes(identity.role) ? (
        <Link className="text-link" href="/tnp/companies">
          Open companies and recruiters
        </Link>
      ) : null}
      <form action={signOut}>
        <button className="text-link" type="submit">
          Sign out
        </button>
      </form>
    </section>
  );
}
