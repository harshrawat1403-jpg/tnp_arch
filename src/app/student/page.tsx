import Link from "next/link";

import { getStudentProfileData } from "@/lib/student-profile/data";

export const dynamic = "force-dynamic";

export default async function StudentDashboardPage() {
  const profile = await getStudentProfileData();

  return (
    <section className="student-page" aria-labelledby="student-dashboard-title">
      <p className="foundation__eyebrow">Student profile</p>
      <h1 id="student-dashboard-title">Welcome, {profile.identity.displayName}.</h1>
      <p className="student-page__summary">
        This workspace currently shows only your profile readiness. Placement workflows will appear
        only in their approved phases.
      </p>
      <div className="student-status" aria-live="polite">
        <p className="student-status__label">Profile readiness</p>
        <p className="student-status__value">
          {profile.completeness.isComplete ? "Complete" : "Action needed"}
        </p>
        {profile.completeness.isComplete ? (
          <p>Your required profile information is present.</p>
        ) : (
          <>
            <p>Complete the following items before TNP verification can proceed:</p>
            <ul>
              {profile.completeness.missingItems.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
          </>
        )}
        <Link className="button" href="/student/profile">
          Review my profile
        </Link>
      </div>
      <dl className="student-status__facts">
        <div>
          <dt>Profile verification</dt>
          <dd>{profile.personalProfile.verificationStatus}</dd>
        </div>
        <div>
          <dt>Academic verification</dt>
          <dd>{profile.academicRecord?.verificationStatus ?? "PENDING"}</dd>
        </div>
      </dl>
    </section>
  );
}
