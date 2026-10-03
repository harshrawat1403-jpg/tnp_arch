import Link from "next/link";
import { deadlineLabel, REASON_LABELS } from "@/lib/drives/presentation";
import type { DriveRow } from "@/lib/drives/data";
import { DRIVE_TYPES, type DriveType } from "@/lib/drives/validation";
import { pageItems, parsePageParameter } from "@/lib/pagination";
import { requireStudentIdentity } from "@/lib/student-profile/data";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export default async function StudentDrivesPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string | string[]; type?: string }>;
}) {
  await requireStudentIdentity();
  const parameters = await searchParams;
  const page = parsePageParameter(parameters.page);
  const type = DRIVE_TYPES.includes(parameters.type as DriveType) ? parameters.type : null;
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("student_drive_list", { p_page: page, p_type: type });
  if (error) throw new Error("Unable to load published drives.");
  const rows = pageItems(data as DriveRow[]);
  const href = (number: number) => `/student/drives?page=${number}${type ? `&type=${type}` : ""}`;
  return (
    <section className="student-page" aria-labelledby="student-drives-title">
      <p className="foundation__eyebrow">Student opportunities</p>
      <h1 id="student-drives-title">Published drives</h1>
      <p className="student-page__summary">
        Review opportunities and your current database-derived eligibility. Applications are not
        available in this phase.
      </p>
      <form action="/student/drives" method="get" className="profile-form">
        <fieldset>
          <legend>Opportunity type</legend>
          <label htmlFor="student-drive-type">Type</label>
          <select id="student-drive-type" name="type" defaultValue={type ?? ""}>
            <option value="">All</option>
            {DRIVE_TYPES.map((value) => (
              <option key={value}>{value}</option>
            ))}
          </select>
          <button type="submit" className="button">
            Filter
          </button>
        </fieldset>
      </form>
      <section className="skills-list" aria-label="Published opportunities">
        {rows.items.length ? (
          rows.items.map((drive) => (
            <article className="skill-record" key={drive.id}>
              <h2>{drive.title}</h2>
              <p>
                {drive.company_name} · {drive.drive_type}
              </p>
              <p>{drive.location ?? "Location not specified"}</p>
              <p>Deadline: {deadlineLabel(drive.application_deadline)}</p>
              <p>
                Criteria: {drive.eligibility?.academic_result}. Availability:{" "}
                {drive.eligibility?.availability === "OPEN" ? "Open" : "Deadline passed"}.
              </p>
              <ul>
                {drive.eligibility?.reason_codes.map((code) => (
                  <li key={code}>{REASON_LABELS[code] ?? "Eligibility unavailable."}</li>
                ))}
              </ul>
              {drive.last_material_change_notice ? (
                <p>Latest correction: {drive.last_material_change_notice}</p>
              ) : null}
              <Link className="text-link" href={`/student/drives/${drive.id}`}>
                View opportunity and eligibility
              </Link>
            </article>
          ))
        ) : (
          <p>No published drives match this filter.</p>
        )}
      </section>
      <nav className="pagination" aria-label="Published drive pagination">
        {page > 1 ? <Link href={href(page - 1)}>Previous</Link> : <span>Previous</span>}
        <span>Page {page}</span>
        {rows.hasNext ? <Link href={href(page + 1)}>Next</Link> : <span>Next</span>}
      </nav>
    </section>
  );
}
