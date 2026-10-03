import Link from "next/link";
import { DriveForm } from "@/components/drives/drive-form";
import { getCompanyOptions, requireDriveStaff } from "@/lib/drives/data";
import { pageItems, parsePageParameter } from "@/lib/pagination";
import { saveDraft } from "../actions";

export const dynamic = "force-dynamic";
export default async function NewDrivePage({
  searchParams,
}: {
  searchParams: Promise<{ company?: string; companyPage?: string | string[]; error?: string }>;
}) {
  await requireDriveStaff();
  const parameters = await searchParams;
  const page = parsePageParameter(parameters.companyPage);
  const rows = pageItems(await getCompanyOptions(page));
  const company = rows.items.find((item) => item.id === parameters.company);
  return (
    <section className="student-page" aria-labelledby="new-drive-title">
      <p className="foundation__eyebrow">TNP administration</p>
      <h1 id="new-drive-title">Create drive draft</h1>
      <Link href="/tnp/drives" className="text-link">
        All drives
      </Link>
      {parameters.error ? (
        <p className="auth-panel__message" role="alert">
          {parameters.error.slice(0, 300)}
        </p>
      ) : null}
      <form action="/tnp/drives/new" method="get" className="profile-form">
        <fieldset>
          <legend>Select an active company</legend>
          <input type="hidden" name="companyPage" value={page} />
          <label htmlFor="new-company">Company</label>
          <select id="new-company" name="company" defaultValue={company?.id} required>
            {rows.items.map((item) => (
              <option key={item.id} value={item.id}>
                {item.name}
              </option>
            ))}
          </select>
          <button type="submit" className="button">
            Choose company
          </button>
        </fieldset>
      </form>
      <nav className="pagination" aria-label="Company selection pagination">
        {page > 1 ? (
          <Link href={`/tnp/drives/new?companyPage=${page - 1}`}>Previous companies</Link>
        ) : null}
        {rows.hasNext ? (
          <Link href={`/tnp/drives/new?companyPage=${page + 1}`}>Next companies</Link>
        ) : null}
      </nav>
      {!rows.items.length ? (
        <p>Create an active company record first.</p>
      ) : company ? (
        <DriveForm action={saveDraft} company={company} />
      ) : (
        <p>Choose a company to enter the draft.</p>
      )}
    </section>
  );
}
