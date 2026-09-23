import { describe, expect, it } from "vitest";

import {
  createResumePath,
  maximumResumeBytes,
  normalizeInstitutionalEmail,
  validateAcademicInput,
  validatePersonalProfileInput,
  validateRegistrationInput,
  validateResumeFile,
} from "./validation";

describe("student profile validation", () => {
  it("normalizes roster-matched registration input without accepting a role", () => {
    expect(normalizeInstitutionalEmail(" Student@Example.Test ")).toBe("student@example.test");
    expect(
      validateRegistrationInput({
        displayName: "Student One",
        email: " Student@Example.Test ",
        password: "safe-password",
      }),
    ).toEqual({
      ok: true,
      value: {
        displayName: "Student One",
        email: "student@example.test",
        password: "safe-password",
      },
    });
  });

  it("rejects invalid personal and academic values", () => {
    expect(
      validatePersonalProfileInput({
        displayName: "Student",
        phoneNumber: "not a number",
        portfolioUrl: "",
      }),
    ).toEqual({ ok: false, message: "Enter a valid phone number." });
    expect(validateAcademicInput({ cgpa: "10.1", activeBacklogCount: "0" })).toEqual({
      ok: false,
      message: "CGPA must be between 0 and 10.",
    });
  });

  it("validates resume MIME type, size, signature, and owner-scoped path", async () => {
    const valid = new File(["%PDF-1.7"], "resume.pdf", { type: "application/pdf" });
    const invalidSignature = new File(["not a pdf"], "resume.pdf", { type: "application/pdf" });
    const invalidType = new File(["%PDF-1.7"], "resume.txt", { type: "text/plain" });
    const oversized = new File([new Uint8Array(maximumResumeBytes + 1)], "resume.pdf", {
      type: "application/pdf",
    });

    await expect(validateResumeFile(valid)).resolves.toMatchObject({ ok: true });
    await expect(validateResumeFile(invalidSignature)).resolves.toEqual({
      ok: false,
      message: "Your resume must be a valid PDF.",
    });
    await expect(validateResumeFile(invalidType)).resolves.toEqual({
      ok: false,
      message: "Your resume must be a PDF.",
    });
    await expect(validateResumeFile(oversized)).resolves.toEqual({
      ok: false,
      message: "Your resume is larger than 5 MB. Choose a smaller PDF.",
    });
    expect(
      createResumePath(
        "11111111-1111-4111-8111-111111111111",
        "22222222-2222-4222-8222-222222222222",
      ),
    ).toEqual({
      ok: true,
      value: "11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.pdf",
    });
  });
});
