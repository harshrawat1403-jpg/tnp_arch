import Link from "next/link";
import { notFound } from "next/navigation";
import { DriveForm } from "@/components/drives/drive-form";
import { DriveSummary } from "@/components/drives/drive-summary";
import { SubmitButton } from "@/components/forms/submit-button";
import { getCompanyOptions, getStaffDrive, requireDriveStaff } from "@/lib/drives/data";
import { isUuid } from "@/lib/drives/validation";
import { pageItems, parsePageParameter } from "@/lib/pagination";
import { correctPublishedDrive, saveDraft, transitionDrive } from "../actions";

export const dynamic = "force-dynamic";
export default async function StaffDrivePage({
  params,
  searchParams,
}: {
  params: Promise<{ driveId: string }>;
  searchParams: Promise<{
    error?: string;
    saved?: string;
    company?: string;
    companyPage?: string | string[];
  }>;
}) {
  const identity = await requireDriveStaff();
  const { driveId } = await params;
  if (!isUuid(driveId)) notFound();
  const drive = await getStaffDrive(driveId);
  if (!drive) notFound();
  const parameters = await searchParams;
  const manager = identity.role !== "TNP_COORDINATOR";
  const next =
    drive.status === "DRAFT"
      ? "PUBLISHED"
      : drive.status === "PUBLISHED"
        ? "CLOSED"
        : drive.status === "CLOSED"
          ? "ARCHIVED"
          : null;
  const page = parsePageParameter(parameters.companyPage);
  const options = drive.status === "DRAFT" ? pageItems(await getCompanyOptions(page)) : null;
  const selected = options?.items.find((item) => item.id === parameters.company);
  return (
    <section className="student-page" aria-labelledby="staff-drive-title">
      <p className="foundation__eyebrow">TNP administration</p>
      <h1 id="staff-drive-title">{drive.title}</h1>
      <p>
        {drive.status} · Revision {drive.revision}
      </p>
      <Link href="/tnp/drives" className="text-link">
        All drives
      </Link>
      {parameters.error ? (
        <p className="auth-panel__message" role="alert">
          {parameters.error.slice(0, 300)}
        </p>
      ) : parameters.saved ? (
        <p role="status">Drive operation recorded.</p>
      ) : null}
      <DriveSummary drive={drive} />
      {options ? (
        <>
          <form action={`/tnp/drives/${drive.id}`} method="get" className="profile-form">
            <fieldset>
              <legend>Change draft company (optional)</legend>
              <label htmlFor="draft-company">Active company</label>
              <input type="hidden" name="companyPage" value={page} />
              <select
                id="draft-company"
                name="company"
                defaultValue={selected?.id ?? drive.company_id}
              >
                {options.items.map((item) => (
                  <option value={item.id} key={item.id}>
                    {item.name}
                  </option>
                ))}
              </select>
              <button className="button" type="submit">
                Choose company for draft form
              </button>
            </fieldset>
          </form>
          <nav className="pagination" aria-label="Company selection pagination">
            {page > 1 ? <Link href={`?companyPage=${page - 1}`}>Previous companies</Link> : null}
            {options.hasNext ? <Link href={`?companyPage=${page + 1}`}>Next companies</Link> : null}
          </nav>
        </>
      ) : null}
      {drive.status === "DRAFT" || (drive.status === "PUBLISHED" && manager) ? (
        <DriveForm
          action={drive.status === "DRAFT" ? saveDraft : correctPublishedDrive}
          drive={drive}
          company={selected ?? { id: drive.company_id, name: drive.company_name }}
        />
      ) : (
        <p>Content is locked in this state or for your role.</p>
      )}
      {manager && next ? (
        <form action={transitionDrive} className="profile-form">
          <fieldset>
            <legend>
              {next === "PUBLISHED" ? "Publish" : next === "CLOSED" ? "Close" : "Archive"} “
              {drive.title}”
            </legend>
            <input name="drive_id" type="hidden" value={drive.id} />
            <input name="revision" type="hidden" value={drive.revision} />
            <input name="next_status" type="hidden" value={next} />
            <p>
              {next === "PUBLISHED"
                ? "Students will see this drive. An active company, complete criteria and future deadline are required."
                : "This removes student visibility. The transition cannot be undone; content and criteria will be locked."}
            </p>
            <SubmitButton>{`Confirm ${next.toLowerCase()}`}</SubmitButton>
          </fieldset>
        </form>
      ) : null}
    </section>
  );
}
