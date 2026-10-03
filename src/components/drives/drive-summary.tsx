import type { DriveDetail, Eligibility } from "@/lib/drives/data";
import { deadlineLabel, REASON_LABELS } from "@/lib/drives/presentation";

export function EligibilitySummary({ eligibility }: { eligibility: Eligibility }) {
  return (
    <section aria-label="Your eligibility">
      <h2>Your eligibility</h2>
      <p>
        Criteria: {eligibility.academic_result}. Availability:{" "}
        {eligibility.availability === "OPEN" ? "Open" : "Deadline passed"}.
      </p>
      <ul>
        {eligibility.reason_codes.map((code) => (
          <li key={code}>{REASON_LABELS[code] ?? "Eligibility is unavailable."}</li>
        ))}
      </ul>
      <p className="form-hint">
        Current database assessment, not an application or an eligibility snapshot. Skills, resume
        readiness and overall profile completeness are not gates.
      </p>
    </section>
  );
}

export function DriveSummary({ drive }: { drive: DriveDetail }) {
  return (
    <div className="skills-list">
      <section>
        <h2>Opportunity</h2>
        <p>
          {drive.company_name} · {drive.drive_type}
        </p>
        <p>{drive.description}</p>
        <p>{drive.location ?? "Location not specified"}</p>
        <p>Deadline: {deadlineLabel(drive.application_deadline)}</p>
      </section>
      <section>
        <h2>Eligibility criteria</h2>
        <ul>
          {drive.eligible_pairs.map((pair) => (
            <li key={`${pair.course}:${pair.batch_year}`}>
              {pair.course} · {pair.batch_year}
            </li>
          ))}
        </ul>
        <p>
          Minimum verified CGPA: {drive.minimum_cgpa}. Maximum active backlogs:{" "}
          {drive.maximum_active_backlogs}.
        </p>
        <p>
          Current previous placement selection excluded:{" "}
          {drive.exclude_previously_selected_placement ? "Yes" : "No"}.
        </p>
      </section>
      <section>
        <h2>Other informational requirements</h2>
        <p>{drive.informational_requirements ?? "None specified."}</p>
      </section>
      <section>
        <h2>Compensation</h2>
        <p>
          Package: {drive.package_lpa == null ? "Not specified" : `${drive.package_lpa} LPA`}.
          Monthly stipend: {drive.stipend_monthly ?? "Not specified"}.
        </p>
        <p>{drive.compensation_details}</p>
      </section>
      {drive.last_material_change_notice ? (
        <section aria-label="Latest correction notice">
          <h2>Latest correction notice</h2>
          <p>{drive.last_material_change_notice}</p>
          <p>{drive.last_material_change_at ? deadlineLabel(drive.last_material_change_at) : ""}</p>
        </section>
      ) : null}
    </div>
  );
}
