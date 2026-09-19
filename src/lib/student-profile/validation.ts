const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const phonePattern = /^[0-9+() -]{7,30}$/;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export const maximumResumeBytes = 5 * 1024 * 1024;

export type ValidationResult<T> = { ok: true; value: T } | { ok: false; message: string };

export function normalizeInstitutionalEmail(value: string): string {
  return value.trim().toLowerCase();
}

export function validateRegistrationInput(input: {
  displayName: string;
  email: string;
  password: string;
}): ValidationResult<{ displayName: string; email: string; password: string }> {
  const displayName = input.displayName.trim();
  const email = normalizeInstitutionalEmail(input.email);

  if (displayName.length < 1 || displayName.length > 160) {
    return { ok: false, message: "Enter your full name." };
  }

  if (!emailPattern.test(email)) {
    return { ok: false, message: "Enter a valid institutional email address." };
  }

  if (input.password.length < 12) {
    return { ok: false, message: "Choose a password with at least 12 characters." };
  }

  return { ok: true, value: { displayName, email, password: input.password } };
}

export function validatePersonalProfileInput(input: {
  displayName: string;
  phoneNumber: string;
  portfolioUrl: string;
  skills: string;
}): ValidationResult<{
  displayName: string;
  phoneNumber: string | null;
  portfolioUrl: string | null;
  skills: string[];
}> {
  const displayName = input.displayName.trim();
  const phoneNumber = input.phoneNumber.trim();
  const portfolioUrl = input.portfolioUrl.trim();
  const skills = Array.from(
    new Set(
      input.skills
        .split(",")
        .map((skill) => skill.trim())
        .filter(Boolean),
    ),
  );

  if (displayName.length < 1 || displayName.length > 160) {
    return { ok: false, message: "Enter your full name." };
  }

  if (phoneNumber && !phonePattern.test(phoneNumber)) {
    return { ok: false, message: "Enter a valid phone number." };
  }

  if (portfolioUrl) {
    try {
      const url = new URL(portfolioUrl);

      if (url.protocol !== "https:") {
        return { ok: false, message: "Use an HTTPS portfolio URL." };
      }
    } catch {
      return { ok: false, message: "Enter a valid HTTPS portfolio URL." };
    }
  }

  if (skills.length > 20 || skills.some((skill) => skill.length > 80)) {
    return { ok: false, message: "Use at most 20 skills of up to 80 characters each." };
  }

  return {
    ok: true,
    value: {
      displayName,
      phoneNumber: phoneNumber || null,
      portfolioUrl: portfolioUrl || null,
      skills,
    },
  };
}

export function validateAcademicInput(input: {
  activeBacklogCount: string;
  cgpa: string;
}): ValidationResult<{ activeBacklogCount: number; cgpa: number }> {
  const cgpa = Number(input.cgpa);
  const activeBacklogCount = Number(input.activeBacklogCount);

  if (!Number.isFinite(cgpa) || cgpa < 0 || cgpa > 10) {
    return { ok: false, message: "CGPA must be between 0 and 10." };
  }

  if (!Number.isInteger(activeBacklogCount) || activeBacklogCount < 0 || activeBacklogCount > 50) {
    return { ok: false, message: "Active backlog count must be a whole number between 0 and 50." };
  }

  return { ok: true, value: { cgpa, activeBacklogCount } };
}

export async function validateResumeFile(file: File): Promise<ValidationResult<File>> {
  if (file.size < 1) {
    return { ok: false, message: "Choose a non-empty PDF resume." };
  }

  if (file.size > maximumResumeBytes) {
    return { ok: false, message: "Your resume is larger than 5 MB. Choose a smaller PDF." };
  }

  if (file.type !== "application/pdf") {
    return { ok: false, message: "Your resume must be a PDF." };
  }

  const header = new TextDecoder().decode(await file.slice(0, 5).arrayBuffer());

  if (header !== "%PDF-") {
    return { ok: false, message: "Your resume must be a valid PDF." };
  }

  return { ok: true, value: file };
}

export function createResumePath(ownerId: string, objectId: string): ValidationResult<string> {
  if (!uuidPattern.test(ownerId) || !uuidPattern.test(objectId)) {
    return { ok: false, message: "Unable to prepare a secure resume upload." };
  }

  return { ok: true, value: `${ownerId.toLowerCase()}/${objectId.toLowerCase()}.pdf` };
}

export function normalizeOriginalFilename(value: string): string {
  const filename = value.trim().replace(/[\\/\u0000-\u001f]/g, "_");
  return filename.slice(0, 255) || "resume.pdf";
}
