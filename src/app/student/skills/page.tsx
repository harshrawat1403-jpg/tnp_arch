import Link from "next/link";

import { SubmitButton } from "@/components/forms/submit-button";
import { requireStudentIdentity } from "@/lib/student-profile/data";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { proficiencyLevels, type SkillVerificationStatus } from "@/lib/student-skills/validation";

import { addProjectEvidence, saveStudentSkill, uploadSkillEvidence } from "./actions";

type StudentSkill = {
  id: string;
  proficiency_level: number;
  reviewer_note: string | null;
  skill: { display_name: string } | null;
  verification_status: SkillVerificationStatus;
};

type CatalogSkill = { id: string; display_name: string };
type Evidence = {
  document_id: string | null;
  id: string;
  project_url: string | null;
  student_skill_id: string;
  title: string;
};

export const dynamic = "force-dynamic";

export default async function StudentSkillsPage({
  searchParams,
}: {
  searchParams: Promise<{ state?: string }>;
}) {
  const identity = await requireStudentIdentity();
  const supabase = await createServerSupabaseClient();
  const [parameters, catalogResult, skillsResult, evidenceResult] = await Promise.all([
    searchParams,
    supabase
      .from("skills")
      .select("id, display_name")
      .eq("is_archived", false)
      .order("display_name"),
    supabase
      .from("student_skills")
      .select(
        "id, proficiency_level, verification_status, reviewer_note, skill:skills(display_name)",
      )
      .eq("student_id", identity.id)
      .order("updated_at", { ascending: false }),
    supabase
      .from("student_skill_evidence")
      .select("id, student_skill_id, title, project_url, document_id")
      .order("created_at", { ascending: false }),
  ]);
  if (catalogResult.error || skillsResult.error || evidenceResult.error) {
    throw new Error("Unable to load student skills.");
  }
  const catalog = catalogResult.data as CatalogSkill[];
  const skills = skillsResult.data as unknown as StudentSkill[];
  const evidenceBySkill = new Map<string, Evidence[]>();
  (evidenceResult.data as Evidence[]).forEach((evidence) => {
    evidenceBySkill.set(evidence.student_skill_id, [
      ...(evidenceBySkill.get(evidence.student_skill_id) ?? []),
      evidence,
    ]);
  });
  const message =
    parameters.state === "saved"
      ? "Your skill has been saved for review."
      : parameters.state === "evidence-saved"
        ? "Your evidence has been saved."
        : parameters.state === "error"
          ? "That skill change could not be completed. Check the details and try again."
          : null;

  return (
    <section className="student-page" aria-labelledby="student-skills-title">
      <p className="foundation__eyebrow">My skills</p>
      <h1 id="student-skills-title">Build a verifiable skills record.</h1>
      <p className="student-page__summary">
        Select a department-approved skill, record your current level, and attach an HTTPS project
        link or private PDF evidence. Verified skills are locked to preserve review integrity.
      </p>
      {message ? (
        <p className="auth-panel__message" role="status">
          {message}
        </p>
      ) : null}

      <div className="profile-layout">
        <form action={saveStudentSkill} className="profile-form">
          <fieldset>
            <legend>Add or resubmit a skill</legend>
            <label htmlFor="skillId">Catalog skill</label>
            <select id="skillId" name="skillId" required>
              <option value="">Choose a skill</option>
              {catalog.map((skill) => (
                <option key={skill.id} value={skill.id}>
                  {skill.display_name}
                </option>
              ))}
            </select>
            <label htmlFor="proficiencyLevel">Proficiency</label>
            <select id="proficiencyLevel" name="proficiencyLevel" required defaultValue="1">
              {proficiencyLevels.map((level) => (
                <option key={level.value} value={level.value}>
                  {level.value} — {level.label}
                </option>
              ))}
            </select>
            <SubmitButton>Save skill</SubmitButton>
          </fieldset>
        </form>

        <section className="skills-list" aria-labelledby="saved-skills-title">
          <h2 id="saved-skills-title">Your submitted skills</h2>
          {skills.length === 0 ? (
            <p>No skills yet. Add one from the approved catalog.</p>
          ) : (
            skills.map((skill) => {
              const editable = skill.verification_status !== "VERIFIED";
              return (
                <article className="skill-record" key={skill.id}>
                  <p className="foundation__eyebrow">{skill.verification_status}</p>
                  <h3>{skill.skill?.display_name ?? "Archived skill"}</h3>
                  <p>
                    Level {skill.proficiency_level} —{" "}
                    {proficiencyLevels[skill.proficiency_level - 1]?.label}
                  </p>
                  {skill.reviewer_note ? (
                    <p className="form-hint">Review note: {skill.reviewer_note}</p>
                  ) : null}
                  {(evidenceBySkill.get(skill.id) ?? []).length > 0 ? (
                    <ul className="skill-record__evidence-list">
                      {(evidenceBySkill.get(skill.id) ?? []).map((evidence) => (
                        <li key={evidence.id}>
                          {evidence.project_url ? (
                            <a href={evidence.project_url} rel="noreferrer" target="_blank">
                              {evidence.title}
                            </a>
                          ) : (
                            <Link href={`/student/skills/evidence/${evidence.id}/download`}>
                              {evidence.title} (private PDF)
                            </Link>
                          )}
                        </li>
                      ))}
                    </ul>
                  ) : null}
                  {editable ? (
                    <div className="skill-record__evidence">
                      <form action={addProjectEvidence} className="profile-form">
                        <fieldset>
                          <legend>Add HTTPS project evidence</legend>
                          <input name="studentSkillId" type="hidden" value={skill.id} />
                          <label>
                            Title
                            <input name="title" required />
                          </label>
                          <label>
                            Project URL
                            <input name="projectUrl" type="url" required placeholder="https://…" />
                          </label>
                          <label>
                            Description <span>(optional)</span>
                            <textarea name="description" rows={2} />
                          </label>
                          <SubmitButton>Add project link</SubmitButton>
                        </fieldset>
                      </form>
                      <form
                        action={uploadSkillEvidence}
                        className="profile-form"
                        encType="multipart/form-data"
                      >
                        <fieldset>
                          <legend>Add private PDF evidence</legend>
                          <input name="studentSkillId" type="hidden" value={skill.id} />
                          <label>
                            Title
                            <input name="title" required />
                          </label>
                          <label>
                            Description <span>(optional)</span>
                            <textarea name="description" rows={2} />
                          </label>
                          <label>
                            PDF evidence
                            <input
                              accept="application/pdf"
                              name="evidenceFile"
                              required
                              type="file"
                            />
                          </label>
                          <SubmitButton pendingChildren="Uploading evidence…">
                            Upload PDF
                          </SubmitButton>
                        </fieldset>
                      </form>
                    </div>
                  ) : (
                    <p className="form-hint">
                      This skill is verified and locked. Contact the TNP office for a correction.
                    </p>
                  )}
                </article>
              );
            })
          )}
        </section>
      </div>
      <Link className="text-link" href="/student/profile">
        Back to my profile
      </Link>
    </section>
  );
}
