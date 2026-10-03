import Link from "next/link";
import { notFound } from "next/navigation";

import { SubmitButton } from "@/components/forms/submit-button";
import { getCurrentIdentity } from "@/lib/supabase/current-identity";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import {
  createRecruiterContact,
  grantRecruiterDriveAccess,
  reissueRecruiterInvitation,
  revokeRecruiterDriveAccess,
  revokeRecruiterInvitation,
  sendRecruiterInvitation,
  setCompanyArchiveState,
  setRecruiterArchiveState,
  updateCompany,
  updateRecruiterContact,
} from "../actions";

type Company = {
  description: string | null;
  id: string;
  is_archived: boolean;
  name: string;
  website_url: string | null;
};
type Recruiter = {
  email: string;
  full_name: string;
  id: string;
  is_archived: boolean;
  phone_number: string | null;
  user_id: string | null;
};
type Invitation = {
  accepted_at: string | null;
  expires_at: string;
  id: string;
  recruiter_id: string;
  revocation_reason: string | null;
  status: "PREPARED" | "SENT" | "ACCEPTED" | "REVOKED" | "DELIVERY_FAILED";
};
type PublishedDrive = { id: string; title: string };
type DriveAccess = {
  drive_id: string;
  expires_at: string | null;
  recruiter_id: string;
  revoked_at: string | null;
};

type DetailSearchParameters = { state?: string | string[] };

const messages: Record<string, string> = {
  "company-created": "The company was created and audited.",
  "company-updated": "The company was updated and audited.",
  "company-archived": "The company was archived. Recruiter access is now ineffective.",
  "company-reactivated":
    "The company was reactivated. Revoked and expired access remains inactive.",
  "recruiter-created": "The recruiter contact was created and audited.",
  "recruiter-updated": "The recruiter contact was updated and audited.",
  "recruiter-archived": "The recruiter contact was archived and access is now ineffective.",
  "recruiter-reactivated": "The recruiter contact was reactivated subject to its existing binding.",
  "invitation-sent": "The recruiter invitation was issued and audited.",
  "invitation-failed": "The invitation provider did not confirm delivery. Retry through reissue.",
  "invitation-finalization-pending":
    "The invitation provider succeeded, but confirmation in the portal could not be completed. Reissue the invitation to recover access; the previous attempt is preserved.",
  "invitation-revoked": "The invitation was revoked and audited.",
  "drive-granted": "Published-drive access was granted and audited.",
  "drive-revoked": "Published-drive access was revoked and audited.",
  error: "That operation was not permitted or could not be completed.",
};

function one(value: string | string[] | undefined): string | undefined {
  return typeof value === "string" ? value : undefined;
}

function activeInvitationFor(
  recruiterId: string,
  invitations: Invitation[],
): Invitation | undefined {
  return invitations.find(
    (invitation) =>
      invitation.recruiter_id === recruiterId &&
      (invitation.status === "PREPARED" || invitation.status === "SENT"),
  );
}

export const dynamic = "force-dynamic";

export default async function CompanyDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ companyId: string }>;
  searchParams: Promise<DetailSearchParameters>;
}) {
  const identity = await getCurrentIdentity();
  if (!identity || !["SUPER_ADMIN", "TNP_SECRETARY", "TNP_COORDINATOR"].includes(identity.role)) {
    return (
      <section className="student-page">
        <h1>Company records are restricted to TNP staff.</h1>
      </section>
    );
  }
  const { companyId } = await params;
  const isManager = identity.role !== "TNP_COORDINATOR";
  const supabase = await createServerSupabaseClient();
  const [companyResult, recruitersResult, invitationsResult, drivesResult, accessResult] =
    await Promise.all([
      supabase
        .from("companies")
        .select("id, name, website_url, description, is_archived")
        .eq("id", companyId)
        .maybeSingle(),
      supabase
        .from("recruiters")
        .select("id, full_name, email, phone_number, user_id, is_archived")
        .eq("company_id", companyId)
        .order("full_name", { ascending: true })
        .order("id", { ascending: true }),
      isManager
        ? supabase
            .from("recruiter_invitations")
            .select("id, recruiter_id, status, expires_at, accepted_at, revocation_reason")
            .order("issued_at", { ascending: false })
            .order("id", { ascending: false })
        : Promise.resolve({ data: [], error: null }),
      isManager
        ? supabase
            .from("placement_drives")
            .select("id, title")
            .eq("company_id", companyId)
            .eq("status", "PUBLISHED")
            .order("title", { ascending: true })
        : Promise.resolve({ data: [], error: null }),
      isManager
        ? supabase
            .from("recruiter_drive_access")
            .select("recruiter_id, drive_id, expires_at, revoked_at")
        : Promise.resolve({ data: [], error: null }),
    ]);
  if (
    companyResult.error ||
    recruitersResult.error ||
    invitationsResult.error ||
    drivesResult.error ||
    accessResult.error
  ) {
    throw new Error("Unable to load the company record.");
  }
  if (!companyResult.data) notFound();
  const company = companyResult.data as Company;
  const recruiters = recruitersResult.data as Recruiter[];
  const invitations = invitationsResult.data as Invitation[];
  const drives = drivesResult.data as PublishedDrive[];
  const accessRows = (accessResult.data as DriveAccess[]).filter((access) =>
    recruiters.some((recruiter) => recruiter.id === access.recruiter_id),
  );
  const state = one((await searchParams).state);

  return (
    <section className="student-page" aria-labelledby="company-title">
      <p className="foundation__eyebrow">TNP administration</p>
      <h1 id="company-title">{company.name}</h1>
      <p className="student-page__summary">
        {company.is_archived
          ? "Archived company record. Recruiter access and new invitations are ineffective."
          : "Active company record with bounded recruiter lifecycle controls."}
      </p>
      {state && messages[state] ? (
        <p className="auth-panel__message" role={state === "error" ? "alert" : "status"}>
          {messages[state]}
        </p>
      ) : null}

      <section className="skills-list" aria-labelledby="company-details-title">
        <h2 id="company-details-title">Company details</h2>
        <form action={updateCompany} className="profile-form">
          <fieldset disabled={company.is_archived}>
            <input name="companyId" type="hidden" value={company.id} />
            <label htmlFor="company-name">Company name</label>
            <input
              defaultValue={company.name}
              id="company-name"
              maxLength={160}
              name="name"
              required
            />
            <label htmlFor="company-website">
              Website <span>(HTTPS, optional)</span>
            </label>
            <input
              defaultValue={company.website_url ?? ""}
              id="company-website"
              name="websiteUrl"
              type="url"
            />
            <label htmlFor="company-description">
              Description <span>(optional)</span>
            </label>
            <textarea
              defaultValue={company.description ?? ""}
              id="company-description"
              maxLength={4000}
              name="description"
              rows={4}
            />
            <SubmitButton>Save company</SubmitButton>
          </fieldset>
        </form>
        {isManager ? (
          <form action={setCompanyArchiveState} className="profile-form">
            <input name="companyId" type="hidden" value={company.id} />
            <input name="archived" type="hidden" value={String(!company.is_archived)} />
            <p>
              {company.is_archived
                ? "Reactivation does not restore expired or revoked access."
                : "Archiving immediately disables recruiter access."}
            </p>
            <SubmitButton>
              {company.is_archived ? "Reactivate company" : "Archive company"}
            </SubmitButton>
          </form>
        ) : null}
      </section>

      <section className="skills-list" aria-labelledby="recruiters-title">
        <h2 id="recruiters-title">Recruiter contacts</h2>
        {!company.is_archived ? (
          <form action={createRecruiterContact} className="profile-form">
            <fieldset>
              <legend>Add contact</legend>
              <input name="companyId" type="hidden" value={company.id} />
              <label htmlFor="recruiter-name">Full name</label>
              <input id="recruiter-name" maxLength={160} name="fullName" required />
              <label htmlFor="recruiter-email">Email</label>
              <input id="recruiter-email" name="email" required type="email" />
              <label htmlFor="recruiter-phone">
                Phone <span>(optional)</span>
              </label>
              <input id="recruiter-phone" name="phoneNumber" />
              <SubmitButton>Create contact</SubmitButton>
            </fieldset>
          </form>
        ) : null}
        {recruiters.map((recruiter) => {
          const invitation = activeInvitationFor(recruiter.id, invitations);
          const recruiterAccess = accessRows.filter(
            (access) => access.recruiter_id === recruiter.id,
          );
          return (
            <article className="skill-record" key={recruiter.id}>
              <h3>{recruiter.full_name}</h3>
              <p>
                {recruiter.email}
                {recruiter.phone_number ? ` · ${recruiter.phone_number}` : ""}
              </p>
              <p>
                {recruiter.is_archived
                  ? "Archived"
                  : recruiter.user_id
                    ? "Bound recruiter account"
                    : "Unbound contact"}
              </p>
              {isManager && invitation ? (
                <p>
                  Invitation: {invitation.status} until{" "}
                  {new Date(invitation.expires_at).toLocaleString()}
                </p>
              ) : null}
              {!recruiter.is_archived && !company.is_archived ? (
                <form action={updateRecruiterContact} className="profile-form">
                  <input name="companyId" type="hidden" value={company.id} />
                  <input name="recruiterId" type="hidden" value={recruiter.id} />
                  <label htmlFor={`recruiter-name-${recruiter.id}`}>Full name</label>
                  <input
                    defaultValue={recruiter.full_name}
                    id={`recruiter-name-${recruiter.id}`}
                    maxLength={160}
                    name="fullName"
                    required
                  />
                  <label htmlFor={`recruiter-email-${recruiter.id}`}>Email</label>
                  <input
                    defaultValue={recruiter.email}
                    id={`recruiter-email-${recruiter.id}`}
                    name="email"
                    required
                    type="email"
                  />
                  <label htmlFor={`recruiter-phone-${recruiter.id}`}>
                    Phone <span>(optional)</span>
                  </label>
                  <input
                    defaultValue={recruiter.phone_number ?? ""}
                    id={`recruiter-phone-${recruiter.id}`}
                    name="phoneNumber"
                  />
                  <SubmitButton>Save contact</SubmitButton>
                </form>
              ) : null}
              {isManager ? (
                <>
                  <form action={setRecruiterArchiveState} className="profile-form">
                    <input name="companyId" type="hidden" value={company.id} />
                    <input name="recruiterId" type="hidden" value={recruiter.id} />
                    <input name="archived" type="hidden" value={String(!recruiter.is_archived)} />
                    <SubmitButton>
                      {recruiter.is_archived ? "Reactivate contact" : "Archive contact"}
                    </SubmitButton>
                  </form>
                  {!company.is_archived && !recruiter.is_archived && !recruiter.user_id ? (
                    <>
                      <form
                        action={invitation ? reissueRecruiterInvitation : sendRecruiterInvitation}
                        className="profile-form"
                      >
                        <input name="companyId" type="hidden" value={company.id} />
                        <input name="recruiterId" type="hidden" value={recruiter.id} />
                        <SubmitButton>
                          {invitation ? "Reissue invitation" : "Issue invitation"}
                        </SubmitButton>
                      </form>
                      {invitation ? (
                        <form action={revokeRecruiterInvitation} className="profile-form">
                          <input name="companyId" type="hidden" value={company.id} />
                          <input name="invitationId" type="hidden" value={invitation.id} />
                          <label htmlFor={`invitation-reason-${invitation.id}`}>
                            Revocation reason
                          </label>
                          <textarea
                            id={`invitation-reason-${invitation.id}`}
                            name="reason"
                            required
                            rows={2}
                          />
                          <SubmitButton>Revoke invitation</SubmitButton>
                        </form>
                      ) : null}
                    </>
                  ) : null}
                  {!company.is_archived && !recruiter.is_archived && recruiter.user_id ? (
                    <div className="skill-record__evidence">
                      <form action={grantRecruiterDriveAccess} className="profile-form">
                        <fieldset>
                          <legend>Grant published-drive metadata</legend>
                          <input name="companyId" type="hidden" value={company.id} />
                          <input name="recruiterId" type="hidden" value={recruiter.id} />
                          <label htmlFor={`drive-${recruiter.id}`}>Published drive</label>
                          <select id={`drive-${recruiter.id}`} name="driveId" required>
                            <option value="">Choose a published drive</option>
                            {drives.map((drive) => (
                              <option key={drive.id} value={drive.id}>
                                {drive.title}
                              </option>
                            ))}
                          </select>
                          <label htmlFor={`expiry-${recruiter.id}`}>
                            Expiry <span>(optional)</span>
                          </label>
                          <input
                            id={`expiry-${recruiter.id}`}
                            name="expiresAt"
                            type="datetime-local"
                          />
                          <SubmitButton>Grant access</SubmitButton>
                        </fieldset>
                      </form>
                      {recruiterAccess.map((access) => (
                        <form
                          action={revokeRecruiterDriveAccess}
                          className="profile-form"
                          key={access.drive_id}
                        >
                          <input name="companyId" type="hidden" value={company.id} />
                          <input name="recruiterId" type="hidden" value={recruiter.id} />
                          <input name="driveId" type="hidden" value={access.drive_id} />
                          <p>
                            {access.revoked_at ? "Revoked grant" : "Active grant"}
                            {access.expires_at
                              ? ` until ${new Date(access.expires_at).toLocaleString()}`
                              : ""}
                          </p>
                          {!access.revoked_at ? (
                            <>
                              <label htmlFor={`grant-reason-${recruiter.id}-${access.drive_id}`}>
                                Revocation reason
                              </label>
                              <textarea
                                id={`grant-reason-${recruiter.id}-${access.drive_id}`}
                                name="reason"
                                required
                                rows={2}
                              />
                              <SubmitButton>Revoke access</SubmitButton>
                            </>
                          ) : null}
                        </form>
                      ))}
                    </div>
                  ) : null}
                </>
              ) : null}
            </article>
          );
        })}
      </section>
      <Link className="text-link" href="/tnp/companies">
        Back to company register
      </Link>
    </section>
  );
}
