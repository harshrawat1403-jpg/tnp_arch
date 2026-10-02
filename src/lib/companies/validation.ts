export type ValidationResult<T> = { ok: true; value: T } | { ok: false; message: string };

function optionalText(value: string, maximumLength: number): string | null | false {
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.length <= maximumLength ? trimmed : false;
}

export function validateCompanyInput(input: {
  description: string;
  name: string;
  websiteUrl: string;
}): ValidationResult<{ description: string | null; name: string; websiteUrl: string | null }> {
  const name = input.name.trim();
  const description = optionalText(input.description, 4000);
  const websiteUrl = input.websiteUrl.trim();

  if (!name || name.length > 160) {
    return { ok: false, message: "Enter a company name of up to 160 characters." };
  }
  if (description === false) {
    return { ok: false, message: "Company description must be 4,000 characters or fewer." };
  }
  if (websiteUrl) {
    try {
      if (new URL(websiteUrl).protocol !== "https:") throw new Error("not HTTPS");
    } catch {
      return { ok: false, message: "Use a valid HTTPS company website URL." };
    }
  }

  return { ok: true, value: { name, websiteUrl: websiteUrl || null, description } };
}

export function validateRecruiterInput(input: {
  email: string;
  fullName: string;
  phoneNumber: string;
}): ValidationResult<{ email: string; fullName: string; phoneNumber: string | null }> {
  const fullName = input.fullName.trim();
  const email = input.email.trim().toLowerCase();
  const phoneNumber = optionalText(input.phoneNumber, 30);

  if (!fullName || fullName.length > 160) {
    return { ok: false, message: "Enter a recruiter name of up to 160 characters." };
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return { ok: false, message: "Enter a valid recruiter email address." };
  }
  if (phoneNumber === false || (phoneNumber && !/^[0-9+() -]{7,30}$/.test(phoneNumber))) {
    return { ok: false, message: "Enter a valid phone number, or leave it blank." };
  }

  return { ok: true, value: { fullName, email, phoneNumber } };
}

export function validateFutureOptionalTimestamp(value: string): ValidationResult<string | null> {
  const trimmed = value.trim();
  if (!trimmed) return { ok: true, value: null };
  const timestamp = new Date(trimmed);
  if (Number.isNaN(timestamp.getTime()) || timestamp.getTime() <= Date.now()) {
    return { ok: false, message: "Choose a future expiry date and time, or leave it blank." };
  }
  return { ok: true, value: timestamp.toISOString() };
}

export function validateRequiredReason(value: string): ValidationResult<string> {
  const reason = value.trim();
  return reason.length >= 1 && reason.length <= 2000
    ? { ok: true, value: reason }
    : { ok: false, message: "Provide a reason of up to 2,000 characters." };
}
