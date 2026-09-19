import Link from "next/link";

import { SubmitButton } from "@/components/forms/submit-button";
import { getStudentProfileData } from "@/lib/student-profile/data";

import { saveAcademicRecord, updatePersonalProfile, uploadResume } from "./actions";

type StudentProfilePageProps = {
  searchParams: Promise<{ state?: string | string[] }>;
};

function getState(value: string | string[] | undefined): string | undefined {
  return typeof value === "string" ? value : undefined;
}

function getMessage(state: string | undefined): string | null {
  switch (state) {
    case "personal-saved":
      return "Your personal profile details were saved.";
    case "academic-saved":
      return "Your academic details were saved and remain pending verification.";
    case "resume-uploaded":
      return "Your private resume was uploaded. Any prior resume metadata is archived.";
    case "error":
      return "That change could not be completed. Check the required fields and try again.";
    default:
      return null;
  }
}

export const dynamic = "force-dynamic";

export default async function StudentProfilePage({ searchParams }: StudentProfilePageProps) {
  const [profile, parameters] = await Promise.all([getStudentProfileData(), searchParams]);
  const state = getState(parameters.state);
  const message = getMessage(state);
  const academicIsVerified = profile.academicRecord?.verificationStatus === "VERIFIED";

  return (
    <section className="student-page" aria-labelledby="student-profile-title">
      <p className="foundation__eyebrow">My profile</p>
      <h1 id="student-profile-title">Maintain your student record.</h1>
      <p className="student-page__summary">
        Your roster establishes {profile.roster.course}, batch {profile.roster.batchYear}. Those
        fields are not self-editable.
      </p>
      {message ? (
        <p className="auth-panel__message" role={state === "error" ? "alert" : "status"}>
          {message}
        </p>
      ) : null}

      <div className="profile-layout">
        <form action={updatePersonalProfile} className="profile-form">
          <fieldset>
            <legend>Personal details</legend>
            <label htmlFor="displayName">Full name</label>
            <input
              defaultValue={profile.identity.displayName}
              id="displayName"
              name="displayName"
              required
            />
            <label htmlFor="phoneNumber">Phone number</label>
            <input
              autoComplete="tel"
              defaultValue={profile.personalProfile.phoneNumber ?? ""}
              id="phoneNumber"
              name="phoneNumber"
              inputMode="tel"
              type="tel"
            />
            <label htmlFor="portfolioUrl">
              External portfolio URL <span>(optional)</span>
            </label>
            <input
              defaultValue={profile.personalProfile.portfolioUrl ?? ""}
              id="portfolioUrl"
              name="portfolioUrl"
              placeholder="https://…"
              type="url"
            />
            <label htmlFor="skills">Skills</label>
            <textarea
              defaultValue={profile.personalProfile.skills.join(", ")}
              id="skills"
              name="skills"
              rows={4}
              aria-describedby="skills-hint"
            />
            <p className="form-hint" id="skills-hint">
              Separate up to 20 skills with commas.
            </p>
            <SubmitButton>Save personal details</SubmitButton>
          </fieldset>
        </form>

        <form action={saveAcademicRecord} className="profile-form">
          <fieldset disabled={academicIsVerified}>
            <legend>Academic details</legend>
            <p className="form-hint">
              {academicIsVerified
                ? "Verified academic fields are locked. Contact the TNP office if correction is required."
                : "These details can be edited until the TNP office verifies them."}
            </p>
            <label htmlFor="cgpa">CGPA</label>
            <input
              defaultValue={profile.academicRecord?.cgpa ?? ""}
              id="cgpa"
              max="10"
              min="0"
              name="cgpa"
              required
              step="0.01"
              type="number"
            />
            <label htmlFor="activeBacklogCount">Current active backlogs</label>
            <input
              defaultValue={profile.academicRecord?.activeBacklogCount ?? 0}
              id="activeBacklogCount"
              max="50"
              min="0"
              name="activeBacklogCount"
              required
              step="1"
              type="number"
            />
            {!academicIsVerified ? <SubmitButton>Save academic details</SubmitButton> : null}
          </fieldset>
        </form>

        <form action={uploadResume} className="profile-form" encType="multipart/form-data">
          <fieldset>
            <legend>Private resume</legend>
            <p className="form-hint">
              Upload one PDF of 5 MB or less. Replacements archive prior metadata.
            </p>
            {profile.resume ? (
              <p className="profile-form__current-file">
                Current file:{" "}
                <Link href="/student/resume/download">{profile.resume.originalFilename}</Link>
              </p>
            ) : null}
            <label htmlFor="resume">Resume PDF</label>
            <input accept="application/pdf" id="resume" name="resume" required type="file" />
            <SubmitButton pendingChildren="Uploading resume…">Upload resume</SubmitButton>
          </fieldset>
        </form>
      </div>
    </section>
  );
}
