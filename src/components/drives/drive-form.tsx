import { SubmitButton } from "@/components/forms/submit-button";
import type { DriveDetail } from "@/lib/drives/data";

export function DriveForm({
  action,
  drive,
  company,
}: {
  action: (form: FormData) => Promise<void>;
  drive?: DriveDetail;
  company: { id: string; name: string };
}) {
  const published = drive?.status === "PUBLISHED";
  return (
    <form action={action} className="profile-form">
      <input name="company_id" type="hidden" value={company.id} />
      {drive ? (
        <>
          <input name="drive_id" type="hidden" value={drive.id} />
          <input name="revision" type="hidden" value={drive.revision} />
        </>
      ) : null}
      <fieldset>
        <legend>{published ? "Published correction" : "Draft content and criteria"}</legend>
        <p>
          Company: {company.name}
          {published
            ? " (locked after publication)"
            : " — select another company before saving if necessary."}
        </p>
        <label htmlFor="drive-title">Title</label>
        <input id="drive-title" name="title" defaultValue={drive?.title} maxLength={200} required />
        {published ? (
          <>
            <p>Type: {drive.drive_type} (locked)</p>
            <input name="drive_type" type="hidden" value={drive.drive_type} />
          </>
        ) : (
          <>
            <label htmlFor="drive-type">Type</label>
            <select
              id="drive-type"
              name="drive_type"
              defaultValue={drive?.drive_type ?? "PLACEMENT"}
            >
              <option>PLACEMENT</option>
              <option>INTERNSHIP</option>
            </select>
          </>
        )}
        <label htmlFor="drive-description">Opportunity description</label>
        <textarea
          id="drive-description"
          name="description"
          defaultValue={drive?.description}
          maxLength={10000}
          required
          rows={6}
        />
        <label htmlFor="drive-location">Location (optional)</label>
        <input
          id="drive-location"
          name="location"
          defaultValue={drive?.location ?? ""}
          maxLength={200}
        />
        <label htmlFor="drive-deadline">Deadline, including timezone</label>
        <input
          id="drive-deadline"
          name="application_deadline"
          defaultValue={drive?.application_deadline}
          placeholder="2026-12-01T17:00:00+05:30"
          required
          aria-describedby="deadline-hint"
        />
        <p id="deadline-hint" className="form-hint">
          Use ISO date/time with Z or an explicit offset. Deadline is exclusive. Expired published
          deadlines cannot change.
        </p>
        <label htmlFor="drive-package">Package, LPA (optional)</label>
        <input
          id="drive-package"
          name="package_lpa"
          type="number"
          step="0.01"
          min="0"
          max="99999999.99"
          defaultValue={drive?.package_lpa ?? ""}
        />
        <label htmlFor="drive-stipend">Monthly stipend (optional)</label>
        <input
          id="drive-stipend"
          name="stipend_monthly"
          type="number"
          step="0.01"
          min="0"
          max="99999999.99"
          defaultValue={drive?.stipend_monthly ?? ""}
        />
        <label htmlFor="drive-compensation">Compensation details (optional)</label>
        <textarea
          id="drive-compensation"
          name="compensation_details"
          maxLength={2000}
          defaultValue={drive?.compensation_details ?? ""}
        />
        <label htmlFor="drive-pairs">Eligible course | batch year pairs</label>
        <textarea
          id="drive-pairs"
          name="eligible_pairs"
          required
          rows={4}
          maxLength={13000}
          defaultValue={drive?.eligible_pairs
            .map((pair) => `${pair.course} | ${pair.batch_year}`)
            .join("\n")}
          placeholder={"B.Arch | 2027\nBIM | 2028"}
          aria-describedby="pairs-hint"
        />
        <p id="pairs-hint" className="form-hint">
          One exact pair per line, up to 100. No independent course/batch combinations. Years
          2000–2200.
        </p>
        <label htmlFor="drive-cgpa">Minimum verified CGPA</label>
        <input
          id="drive-cgpa"
          name="minimum_cgpa"
          type="number"
          min="0"
          max="10"
          step="0.01"
          required
          defaultValue={drive?.minimum_cgpa ?? 0}
        />
        <label htmlFor="drive-backlogs">Maximum active backlogs</label>
        <input
          id="drive-backlogs"
          name="maximum_active_backlogs"
          type="number"
          min="0"
          max="50"
          step="1"
          required
          defaultValue={drive?.maximum_active_backlogs ?? 0}
        />
        <label htmlFor="drive-selected">Exclude a current previous placement selection</label>
        <select
          id="drive-selected"
          name="exclude_previously_selected_placement"
          defaultValue={String(drive?.exclude_previously_selected_placement ?? false)}
        >
          <option value="false">No (default)</option>
          <option value="true">Yes</option>
        </select>
        <label htmlFor="drive-information">
          Other informational requirements (not eligibility gates)
        </label>
        <textarea
          id="drive-information"
          name="informational_requirements"
          maxLength={4000}
          defaultValue={drive?.informational_requirements ?? ""}
        />
        {published ? (
          <>
            <p role="note">
              This drive is already visible to students. Every correction, including a typo, is
              audited and may change eligibility.
            </p>
            <label htmlFor="drive-reason">
              Internal audit reason (required, not shown to students)
            </label>
            <textarea id="drive-reason" name="reason" maxLength={2000} required />
            <label htmlFor="drive-notice">Student-facing correction notice (required)</label>
            <textarea id="drive-notice" name="notice" maxLength={2000} required />
          </>
        ) : null}
        <SubmitButton>{published ? "Record published correction" : "Save draft"}</SubmitButton>
      </fieldset>
    </form>
  );
}
