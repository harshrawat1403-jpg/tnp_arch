import Link from "next/link";
import { redirect } from "next/navigation";

import { getCurrentIdentity } from "@/lib/supabase/current-identity";
import { createServerSupabaseClient } from "@/lib/supabase/server";

type Recruiter = {
  company_id: string;
  email: string;
  full_name: string;
  phone_number: string | null;
};
type Company = { description: string | null; name: string; website_url: string | null };
type Drive = {
  application_deadline: string | null;
  drive_type: string;
  location: string | null;
  title: string;
};

export const dynamic = "force-dynamic";

export default async function RecruiterPage() {
  const identity = await getCurrentIdentity();
  if (!identity) redirect("/login?error=invalid&next=/recruiter");
  if (identity.role !== "RECRUITER") {
    return (
      <section className="student-page">
        <h1>Recruiter access is required for this workspace.</h1>
      </section>
    );
  }

  const supabase = await createServerSupabaseClient();
  const { data: recruiterData, error: recruiterError } = await supabase
    .from("recruiters")
    .select("company_id, full_name, email, phone_number")
    .eq("user_id", identity.id)
    .maybeSingle();
  if (recruiterError) throw new Error("Unable to load recruiter access.");
  if (!recruiterData) {
    return (
      <section className="student-page">
        <h1>Your recruiter contact is not active.</h1>
      </section>
    );
  }
  const recruiter = recruiterData as Recruiter;
  const [companyResult, drivesResult] = await Promise.all([
    supabase
      .from("companies")
      .select("name, website_url, description")
      .eq("id", recruiter.company_id)
      .maybeSingle(),
    supabase
      .from("placement_drives")
      .select("title, drive_type, location, application_deadline")
      .order("application_deadline", { ascending: true })
      .order("id", { ascending: true }),
  ]);
  if (companyResult.error || drivesResult.error) {
    throw new Error("Unable to load the recruiter workspace.");
  }
  const company = companyResult.data as Company | null;
  const drives = drivesResult.data as Drive[];

  return (
    <section className="student-page" aria-labelledby="recruiter-title">
      <p className="foundation__eyebrow">Recruiter workspace</p>
      <h1 id="recruiter-title">{recruiter.full_name}</h1>
      <p className="student-page__summary">
        Your approved company contact and published-drive access.
      </p>
      <p>
        <Link className="text-link" href="/recruiter/setup-password">
          Set your sign-in password
        </Link>
      </p>
      <section className="student-status" aria-labelledby="contact-title">
        <p className="student-status__label" id="contact-title">
          Contact
        </p>
        <dl className="student-status__facts">
          <div>
            <dt>Email</dt>
            <dd>{recruiter.email}</dd>
          </div>
          <div>
            <dt>Phone</dt>
            <dd>{recruiter.phone_number ?? "Not provided"}</dd>
          </div>
        </dl>
      </section>
      {company ? (
        <section className="skills-list" aria-labelledby="company-title">
          <h2 id="company-title">{company.name}</h2>
          {company.website_url ? (
            <p>
              <a href={company.website_url} rel="noreferrer" target="_blank">
                Company website
              </a>
            </p>
          ) : null}
          {company.description ? <p>{company.description}</p> : null}
        </section>
      ) : null}
      <section className="skills-list" aria-labelledby="drives-title">
        <h2 id="drives-title">Granted published drives</h2>
        {drives.length === 0 ? (
          <p>No published-drive metadata is currently granted to this account.</p>
        ) : null}
        {drives.map((drive) => (
          <article
            className="skill-record"
            key={`${drive.title}-${drive.application_deadline ?? "none"}`}
          >
            <h3>{drive.title}</h3>
            <p>
              {drive.drive_type}
              {drive.location ? ` · ${drive.location}` : ""}
            </p>
            <p>
              {drive.application_deadline
                ? `Deadline: ${new Date(drive.application_deadline).toLocaleDateString()}`
                : "No deadline provided"}
            </p>
          </article>
        ))}
      </section>
    </section>
  );
}
