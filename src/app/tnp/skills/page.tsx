import Link from "next/link";

import { SubmitButton } from "@/components/forms/submit-button";
import { pageItems, pageRange, parsePageParameter } from "@/lib/pagination";
import { getCurrentIdentity } from "@/lib/supabase/current-identity";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import {
  archiveCatalogSkill,
  assignCoordinatorScope,
  correctVerifiedStudentSkill,
  createCatalogSkill,
  reactivateCatalogSkill,
  removeCoordinatorScope,
  reviewStudentSkill,
  revokeVerifiedStudentSkill,
  updateCatalogSkill,
} from "./actions";

type Skill = { display_name: string } | null;
type SkillEvidence = {
  id: string;
  project_url: string | null;
  source_type: "DOCUMENT" | "PROJECT_URL";
  title: string;
};
type ReviewRow = {
  evidence: SkillEvidence[] | null;
  id: string;
  proficiency_level: number;
  skill: Skill;
  student_id: string;
};
type CatalogSkill = { id: string; display_name: string; is_archived: boolean };
type CoordinatorScope = { coordinator_id: string; course: string; batch_year: number };
type TnpSkillsSearchParameters = {
  pendingPage?: string | string[];
  state?: string | string[];
  verifiedPage?: string | string[];
};

export const dynamic = "force-dynamic";

function isHttpsProjectUrl(value: string | null): value is string {
  if (!value) return false;
  try {
    return new URL(value).protocol === "https:";
  } catch {
    return false;
  }
}

function pageHref(
  parameters: TnpSkillsSearchParameters,
  pendingPage: number,
  verifiedPage: number,
): string {
  const query = new URLSearchParams();
  const state = Array.isArray(parameters.state) ? parameters.state[0] : parameters.state;
  if (state) query.set("state", state);
  if (pendingPage > 1) query.set("pendingPage", String(pendingPage));
  if (verifiedPage > 1) query.set("verifiedPage", String(verifiedPage));
  const serialized = query.toString();

  return serialized ? `/tnp/skills?${serialized}` : "/tnp/skills";
}

function EvidenceList({ evidence }: { evidence: SkillEvidence[] | null }) {
  if (!evidence?.length) return <p>No evidence submitted.</p>;

  return (
    <ul>
      {evidence.map((item) => (
        <li key={item.id}>
          {item.source_type === "PROJECT_URL" && isHttpsProjectUrl(item.project_url) ? (
            <a href={item.project_url} rel="noreferrer" target="_blank">
              {item.title}
            </a>
          ) : item.source_type === "DOCUMENT" ? (
            <Link href={`/tnp/skills/evidence/${item.id}/download`} prefetch={false}>
              {item.title} (private PDF)
            </Link>
          ) : (
            item.title
          )}
        </li>
      ))}
    </ul>
  );
}

function QueuePagination({
  currentPage,
  label,
  nextHref,
  previousHref,
  showNext,
}: {
  currentPage: number;
  label: string;
  nextHref: string;
  previousHref: string;
  showNext: boolean;
}) {
  if (currentPage === 1 && !showNext) return null;

  return (
    <nav aria-label={`${label} pagination`} className="pagination">
      {currentPage > 1 ? <Link href={previousHref}>Previous</Link> : <span>Previous</span>}
      <span>Page {currentPage}</span>
      {showNext ? <Link href={nextHref}>Next</Link> : <span>Next</span>}
    </nav>
  );
}

export default async function TnpSkillsPage({
  searchParams,
}: {
  searchParams: Promise<TnpSkillsSearchParameters>;
}) {
  const identity = await getCurrentIdentity();
  if (!identity || !["SUPER_ADMIN", "TNP_SECRETARY", "TNP_COORDINATOR"].includes(identity.role)) {
    return (
      <section className="student-page">
        <h1>Skill review is restricted to TNP staff.</h1>
      </section>
    );
  }

  const parameters = await searchParams;
  const pendingPage = parsePageParameter(parameters.pendingPage);
  const verifiedPage = parsePageParameter(parameters.verifiedPage);
  const pendingRange = pageRange(pendingPage);
  const verifiedRange = pageRange(verifiedPage);
  const supabase = await createServerSupabaseClient();
  const canManageCatalog = identity.role !== "TNP_COORDINATOR";
  const skillProjection =
    "id, student_id, proficiency_level, skill:skills(display_name), evidence:student_skill_evidence(id, title, source_type, project_url)";
  const [queueResult, catalogResult, scopesResult, verifiedResult] = await Promise.all([
    supabase
      .from("student_skills")
      .select(skillProjection)
      .eq("verification_status", "PENDING")
      .order("updated_at", { ascending: true })
      .order("id", { ascending: true })
      .range(pendingRange.from, pendingRange.to),
    canManageCatalog
      ? supabase
          .from("skills")
          .select("id, display_name, is_archived")
          .order("display_name")
          .limit(100)
      : Promise.resolve({ data: [], error: null }),
    canManageCatalog
      ? supabase
          .from("coordinator_student_scopes")
          .select("coordinator_id, course, batch_year")
          .order("course")
          .limit(100)
      : Promise.resolve({ data: [], error: null }),
    canManageCatalog
      ? supabase
          .from("student_skills")
          .select(skillProjection)
          .eq("verification_status", "VERIFIED")
          .order("updated_at", { ascending: false })
          .order("id", { ascending: true })
          .range(verifiedRange.from, verifiedRange.to)
      : Promise.resolve({ data: [], error: null }),
  ]);
  if (queueResult.error || catalogResult.error || scopesResult.error || verifiedResult.error) {
    throw new Error("Unable to load bounded skill administration data.");
  }

  const pending = pageItems(queueResult.data as unknown as ReviewRow[]);
  const verified = pageItems(verifiedResult.data as unknown as ReviewRow[]);
  const catalog = catalogResult.data as CatalogSkill[];
  const scopes = scopesResult.data as CoordinatorScope[];
  const messages: Record<string, string> = {
    "catalog-saved": "The catalog skill was created and audited.",
    "catalog-updated": "The catalog skill was updated and audited.",
    "catalog-archived":
      "The catalog skill was archived. Historical student records remain available.",
    "catalog-reactivated": "The catalog skill is active and selectable again.",
    "scope-saved": "The coordinator scope assignment was recorded and audited.",
    "scope-removed": "The coordinator scope removal was recorded and audited.",
    reviewed: "The skill review was recorded.",
    "verified-skill-corrected": "The verified skill correction was recorded and audited.",
    "verified-skill-revoked":
      "The verified skill was returned to pending review and the revocation was audited.",
    error: "That operation was not permitted or could not be completed.",
  };
  const state = Array.isArray(parameters.state) ? parameters.state[0] : parameters.state;
  const message = state ? messages[state] : null;

  return (
    <section className="student-page" aria-labelledby="tnp-skills-title">
      <p className="foundation__eyebrow">TNP administration</p>
      <h1 id="tnp-skills-title">Bounded skill review</h1>
      <p className="student-page__summary">
        This queue is database-scoped. Coordinators see only assigned course and batch records.
      </p>
      {message ? (
        <p className="auth-panel__message" role="status">
          {message}
        </p>
      ) : null}
      {canManageCatalog ? (
        <>
          <section className="skills-list" aria-labelledby="catalog-title">
            <h2 id="catalog-title">Skill catalog</h2>
            <form action={createCatalogSkill} className="profile-form">
              <fieldset>
                <legend>Create canonical skill</legend>
                <label htmlFor="displayName">Skill name</label>
                <input id="displayName" name="displayName" maxLength={120} required />
                <SubmitButton>Create catalog skill</SubmitButton>
              </fieldset>
            </form>
            {catalog.map((skill) => (
              <article className="skill-record" key={skill.id}>
                <h3>{skill.display_name}</h3>
                <p>
                  {skill.is_archived
                    ? "Archived: unavailable for new student selection."
                    : "Active: available for new student selection."}
                </p>
                <form action={updateCatalogSkill} className="profile-form">
                  <input name="skillId" type="hidden" value={skill.id} />
                  <label htmlFor={`catalog-${skill.id}`}>Canonical skill name</label>
                  <input
                    id={`catalog-${skill.id}`}
                    name="displayName"
                    defaultValue={skill.display_name}
                    maxLength={120}
                    required
                  />
                  <SubmitButton>Save name</SubmitButton>
                </form>
                {skill.is_archived ? (
                  <form action={reactivateCatalogSkill} className="profile-form">
                    <input name="skillId" type="hidden" value={skill.id} />
                    <p>Reactivation makes this canonical skill selectable again.</p>
                    <SubmitButton>Reactivate skill</SubmitButton>
                  </form>
                ) : (
                  <form action={archiveCatalogSkill} className="profile-form">
                    <input name="skillId" type="hidden" value={skill.id} />
                    <label htmlFor={`archive-${skill.id}`}>Type ARCHIVE to confirm</label>
                    <input id={`archive-${skill.id}`} name="archiveConfirmation" required />
                    <p>Archiving preserves historical student records and stops new selection.</p>
                    <SubmitButton>Archive skill</SubmitButton>
                  </form>
                )}
              </article>
            ))}
          </section>
          <section className="skills-list" aria-labelledby="scope-title">
            <h2 id="scope-title">Coordinator course and batch scopes</h2>
            <p>
              Only an active coordinator can receive a scope. Database procedures enforce the role
              and derive the acting authority.
            </p>
            <form action={assignCoordinatorScope} className="profile-form">
              <fieldset>
                <legend>Assign explicit scope</legend>
                <label htmlFor="coordinatorId">Coordinator account ID</label>
                <input id="coordinatorId" name="coordinatorId" required />
                <label htmlFor="course">Course</label>
                <input id="course" name="course" maxLength={120} required />
                <label htmlFor="batchYear">Batch year</label>
                <input
                  id="batchYear"
                  name="batchYear"
                  type="number"
                  min="2000"
                  max="2200"
                  required
                />
                <SubmitButton>Assign scope</SubmitButton>
              </fieldset>
            </form>
            {scopes.map((scope) => (
              <article
                className="skill-record"
                key={`${scope.coordinator_id}-${scope.course}-${scope.batch_year}`}
              >
                <h3>
                  {scope.course} · {scope.batch_year}
                </h3>
                <p>Coordinator: {scope.coordinator_id}</p>
                <form action={removeCoordinatorScope} className="profile-form">
                  <input name="coordinatorId" type="hidden" value={scope.coordinator_id} />
                  <input name="course" type="hidden" value={scope.course} />
                  <input name="batchYear" type="hidden" value={scope.batch_year} />
                  <SubmitButton>Remove scope</SubmitButton>
                </form>
              </article>
            ))}
          </section>
        </>
      ) : null}
      <section className="skills-list" aria-labelledby="review-queue-title">
        <h2 id="review-queue-title">Pending review</h2>
        {pending.items.length === 0 ? (
          <p>No pending skills are available in your scope.</p>
        ) : (
          pending.items.map((skill) => (
            <article className="skill-record" key={skill.id}>
              <h3>{skill.skill?.display_name ?? "Skill"}</h3>
              <p>Student record: {skill.student_id}</p>
              <p>Claimed proficiency: {skill.proficiency_level}</p>
              <h4>Submitted evidence</h4>
              <EvidenceList evidence={skill.evidence} />
              <form action={reviewStudentSkill} className="profile-form">
                <fieldset>
                  <legend>Review</legend>
                  <input name="studentSkillId" type="hidden" value={skill.id} />
                  <label htmlFor={`status-${skill.id}`}>Decision</label>
                  <select
                    id={`status-${skill.id}`}
                    name="verificationStatus"
                    defaultValue="VERIFIED"
                  >
                    <option value="VERIFIED">Verify</option>
                    <option value="REJECTED">Reject</option>
                  </select>
                  <label htmlFor={`note-${skill.id}`}>
                    Review note <span>(required for rejection)</span>
                  </label>
                  <textarea id={`note-${skill.id}`} name="reviewerNote" rows={2} />
                  <SubmitButton>Record review</SubmitButton>
                </fieldset>
              </form>
            </article>
          ))
        )}
        <QueuePagination
          currentPage={pendingPage}
          label="Pending review"
          nextHref={pageHref(parameters, pendingPage + 1, verifiedPage)}
          previousHref={pageHref(parameters, pendingPage - 1, verifiedPage)}
          showNext={pending.hasNext}
        />
      </section>
      {canManageCatalog ? (
        <section className="skills-list" aria-labelledby="verified-title">
          <h2 id="verified-title">Verified-skill corrections</h2>
          <p>
            Students cannot edit verified skills. Every correction or revocation requires a reason
            and is audited.
          </p>
          {verified.items.length === 0 ? (
            <p>No verified skills are available.</p>
          ) : (
            verified.items.map((skill) => (
              <article className="skill-record" key={skill.id}>
                <h3>{skill.skill?.display_name ?? "Skill"}</h3>
                <p>
                  Student record: {skill.student_id} · Level {skill.proficiency_level}
                </p>
                <h4>Submitted evidence</h4>
                <EvidenceList evidence={skill.evidence} />
                <form action={correctVerifiedStudentSkill} className="profile-form">
                  <input name="studentSkillId" type="hidden" value={skill.id} />
                  <label htmlFor={`level-${skill.id}`}>Correct proficiency</label>
                  <select
                    id={`level-${skill.id}`}
                    name="proficiencyLevel"
                    defaultValue={skill.proficiency_level}
                  >
                    {[1, 2, 3, 4].map((level) => (
                      <option key={level} value={level}>
                        Level {level}
                      </option>
                    ))}
                  </select>
                  <label htmlFor={`correction-${skill.id}`}>Mandatory correction reason</label>
                  <textarea id={`correction-${skill.id}`} name="reason" required rows={2} />
                  <SubmitButton>Correct verified skill</SubmitButton>
                </form>
                <form action={revokeVerifiedStudentSkill} className="profile-form">
                  <input name="studentSkillId" type="hidden" value={skill.id} />
                  <label htmlFor={`revoke-${skill.id}`}>Mandatory revocation reason</label>
                  <textarea id={`revoke-${skill.id}`} name="reason" required rows={2} />
                  <SubmitButton>Revoke to pending review</SubmitButton>
                </form>
              </article>
            ))
          )}
          <QueuePagination
            currentPage={verifiedPage}
            label="Verified-skill corrections"
            nextHref={pageHref(parameters, pendingPage, verifiedPage + 1)}
            previousHref={pageHref(parameters, pendingPage, verifiedPage - 1)}
            showNext={verified.hasNext}
          />
        </section>
      ) : null}
    </section>
  );
}
