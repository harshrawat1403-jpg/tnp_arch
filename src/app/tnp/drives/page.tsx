import Link from "next/link";
import { requireDriveStaff, type DriveRow } from "@/lib/drives/data";
import { DRIVE_STATUSES, type DriveStatus } from "@/lib/drives/validation";
import { deadlineLabel } from "@/lib/drives/presentation";
import { pageItems, parsePageParameter } from "@/lib/pagination";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export default async function StaffDrivesPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string | string[]; status?: string }>;
}) {
  await requireDriveStaff();
  const parameters = await searchParams;
  const status = DRIVE_STATUSES.includes(parameters.status as DriveStatus)
    ? (parameters.status as DriveStatus)
    : "DRAFT";
  const page = parsePageParameter(parameters.page);
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("staff_drive_list", {
    p_page: page,
    p_status: status,
  });
  if (error) throw new Error("Unable to load drives.");
  const rows = pageItems(data as DriveRow[]);
  const href = (number: number) => `/tnp/drives?status=${status}&page=${number}`;
  return (
    <section className="student-page" aria-labelledby="drives-title">
      <p className="foundation__eyebrow">TNP administration</p>
      <h1 id="drives-title">Drives and eligibility</h1>
      <Link href="/tnp/drives/new" className="text-link">
        Create draft
      </Link>
      <form action="/tnp/drives" method="get" className="profile-form">
        <fieldset>
          <legend>Lifecycle filter</legend>
          <label htmlFor="drive-status">State</label>
          <select id="drive-status" name="status" defaultValue={status}>
            {DRIVE_STATUSES.map((state) => (
              <option key={state}>{state}</option>
            ))}
          </select>
          <button className="button" type="submit">
            Filter
          </button>
        </fieldset>
      </form>
      <section className="skills-list" aria-label="Drive records">
        {rows.items.length ? (
          rows.items.map((drive) => (
            <article className="skill-record" key={drive.id}>
              <h2>{drive.title}</h2>
              <p>
                {drive.company_name} · {drive.drive_type} · {drive.status}
              </p>
              <p>Deadline: {deadlineLabel(drive.application_deadline)}</p>
              <Link href={`/tnp/drives/${drive.id}`} className="text-link">
                Open drive
              </Link>
            </article>
          ))
        ) : (
          <p>No drives in this state.</p>
        )}
      </section>
      <nav className="pagination" aria-label="Drive pagination">
        {page > 1 ? <Link href={href(page - 1)}>Previous</Link> : <span>Previous</span>}
        <span>Page {page}</span>
        {rows.hasNext ? <Link href={href(page + 1)}>Next</Link> : <span>Next</span>}
      </nav>
    </section>
  );
}
