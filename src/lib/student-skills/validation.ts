export const proficiencyLevels = [
  { value: 1, label: "Foundation" },
  { value: 2, label: "Working" },
  { value: 3, label: "Applied" },
  { value: 4, label: "Advanced" },
] as const;

export type SkillVerificationStatus = "PENDING" | "VERIFIED" | "REJECTED";

export type ValidationResult<T> = { ok: true; value: T } | { ok: false; message: string };

export function validateProficiency(value: string): ValidationResult<number> {
  const proficiency = Number(value);
  return Number.isInteger(proficiency) && proficiency >= 1 && proficiency <= 4
    ? { ok: true, value: proficiency }
    : { ok: false, message: "Choose a proficiency level from 1 to 4." };
}

export function validateProjectEvidence(input: {
  description: string;
  title: string;
  url: string;
}): ValidationResult<{ description: string | null; title: string; url: string }> {
  const title = input.title.trim();
  const description = input.description.trim();
  const url = input.url.trim();

  if (!title || title.length > 200) {
    return { ok: false, message: "Enter an evidence title of up to 200 characters." };
  }
  if (description.length > 2000) {
    return { ok: false, message: "Evidence description must be 2,000 characters or fewer." };
  }
  try {
    if (new URL(url).protocol !== "https:") {
      return { ok: false, message: "Use an HTTPS project URL." };
    }
  } catch {
    return { ok: false, message: "Use a valid HTTPS project URL." };
  }
  return { ok: true, value: { title, description: description || null, url } };
}

export function createSkillEvidencePath(ownerId: string, objectId: string): string {
  return `${ownerId.toLowerCase()}/${objectId.toLowerCase()}.pdf`;
}
