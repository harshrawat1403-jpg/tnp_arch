import type { ValidationResult } from "../companies/validation";

export const DRIVE_TYPES = ["PLACEMENT", "INTERNSHIP"] as const;
export const DRIVE_STATUSES = ["DRAFT", "PUBLISHED", "CLOSED", "ARCHIVED"] as const;
export type DriveType = (typeof DRIVE_TYPES)[number];
export type DriveStatus = (typeof DRIVE_STATUSES)[number];
export type EligiblePair = { course: string; batch_year: number };
export type DriveContent = {
  company_id: string;
  title: string;
  drive_type: DriveType;
  description: string;
  location: string | null;
  application_deadline: string;
  package_lpa: number | null;
  stipend_monthly: number | null;
  compensation_details: string | null;
  minimum_cgpa: number;
  maximum_active_backlogs: number;
  exclude_previously_selected_placement: boolean;
  informational_requirements: string | null;
  eligible_pairs: EligiblePair[];
};

export function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

export function parseRevision(value: string): number | null {
  if (!/^[1-9]\d*$/.test(value)) return null;
  const revision = Number(value);
  return Number.isSafeInteger(revision) && revision <= 2147483647 ? revision : null;
}

// Form transport only. Eligibility decisions are exclusively PostgreSQL-owned.
export function parseEligiblePairs(value: string): ValidationResult<EligiblePair[]> {
  const lines = value.trim().split(/\r?\n/);
  if (!value.trim() || lines.length > 100) {
    return { ok: false, message: "Provide 1–100 explicit course | batch year pairs." };
  }
  const pairs: EligiblePair[] = [];
  const seen = new Set<string>();
  for (const line of lines) {
    const fields = line.split("|");
    const course = fields[0]?.trim() ?? "";
    const year = fields[1]?.trim() ?? "";
    const batch_year = Number(year);
    if (
      fields.length !== 2 ||
      !course ||
      course.length > 120 ||
      !/^\d{4}$/.test(year) ||
      batch_year < 2000 ||
      batch_year > 2200
    )
      return {
        ok: false,
        message: "Use one course | batch year pair per line; years must be 2000–2200.",
      };
    const key = JSON.stringify([course, batch_year]);
    if (seen.has(key)) return { ok: false, message: "Remove duplicate course/batch pairs." };
    seen.add(key);
    pairs.push({ course, batch_year });
  }
  return { ok: true, value: pairs };
}

function numeric(value: string, maximum: number, optional = false): number | null | false {
  if (!value.trim()) return optional ? null : false;
  if (!/^\d+(\.\d{1,2})?$/.test(value.trim())) return false;
  const number = Number(value);
  return Number.isFinite(number) && number >= 0 && number <= maximum ? number : false;
}

export function validateDriveForm(form: FormData): ValidationResult<DriveContent> {
  const text = (name: string) => {
    const value = form.get(name);
    return typeof value === "string" ? value.trim() : "";
  };
  const title = text("title");
  const description = text("description");
  const company_id = text("company_id");
  const type = text("drive_type");
  const minimum_cgpa = numeric(text("minimum_cgpa"), 10);
  const maximum_active_backlogs = numeric(text("maximum_active_backlogs"), 50);
  const package_lpa = numeric(text("package_lpa"), 99999999.99, true);
  const stipend_monthly = numeric(text("stipend_monthly"), 99999999.99, true);
  const date = text("application_deadline");
  // Explicit UTC/offset required: a server's local timezone is never authority.
  const deadline = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+-]\d{2}:\d{2})$/.test(
    date,
  )
    ? new Date(date)
    : new Date(NaN);
  const year = Number(date.slice(0, 4));
  const month = Number(date.slice(5, 7));
  const day = Number(date.slice(8, 10));
  const validCalendar =
    month >= 1 && month <= 12 && day >= 1 && day <= new Date(Date.UTC(year, month, 0)).getUTCDate();
  const pairs = parseEligiblePairs(text("eligible_pairs"));
  if (!pairs.ok) return pairs;
  if (
    !isUuid(company_id) ||
    !title ||
    title.length > 200 ||
    !description ||
    description.length > 10000 ||
    !DRIVE_TYPES.includes(type as DriveType) ||
    Number.isNaN(deadline.getTime()) ||
    !validCalendar ||
    minimum_cgpa === false ||
    minimum_cgpa === null ||
    maximum_active_backlogs === false ||
    maximum_active_backlogs === null ||
    !Number.isInteger(maximum_active_backlogs) ||
    package_lpa === false ||
    stipend_monthly === false ||
    text("location").length > 200 ||
    text("compensation_details").length > 2000 ||
    text("informational_requirements").length > 4000
  )
    return {
      ok: false,
      message: "Check the required fields, numeric ranges and timezone-qualified deadline.",
    };
  return {
    ok: true,
    value: {
      company_id,
      title,
      description,
      drive_type: type as DriveType,
      // Preserve PostgreSQL microseconds, particularly unchanged expired deadlines.
      application_deadline: date,
      minimum_cgpa,
      maximum_active_backlogs,
      package_lpa,
      stipend_monthly,
      location: text("location") || null,
      compensation_details: text("compensation_details") || null,
      informational_requirements: text("informational_requirements") || null,
      exclude_previously_selected_placement:
        text("exclude_previously_selected_placement") === "true",
      eligible_pairs: pairs.value,
    },
  };
}
