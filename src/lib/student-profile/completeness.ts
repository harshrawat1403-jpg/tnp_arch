export const studentProfileRequiredItems = [
  "Full name",
  "Phone number",
  "At least one skill",
  "Academic record",
  "Resume",
] as const;

export type StudentProfileRequiredItem = (typeof studentProfileRequiredItems)[number];

export type StudentProfileCompletenessInput = {
  activeResumeId: string | null;
  displayName: string | null;
  hasAcademicRecord: boolean;
  hasStudentSkill: boolean;
  phoneNumber: string | null;
};

export type StudentProfileCompleteness = {
  isComplete: boolean;
  missingItems: StudentProfileRequiredItem[];
};

export function getStudentProfileCompleteness(
  input: StudentProfileCompletenessInput,
): StudentProfileCompleteness {
  const missingItems: StudentProfileRequiredItem[] = [];

  if (!input.displayName?.trim()) {
    missingItems.push("Full name");
  }

  if (!input.phoneNumber?.trim()) {
    missingItems.push("Phone number");
  }

  if (!input.hasStudentSkill) {
    missingItems.push("At least one skill");
  }

  if (!input.hasAcademicRecord) {
    missingItems.push("Academic record");
  }

  if (!input.activeResumeId) {
    missingItems.push("Resume");
  }

  return { isComplete: missingItems.length === 0, missingItems };
}
