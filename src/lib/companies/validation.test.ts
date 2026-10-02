import { describe, expect, it } from "vitest";

import {
  validateCompanyInput,
  validateFutureOptionalTimestamp,
  validateRecruiterInput,
  validateRequiredReason,
} from "./validation";

describe("company and recruiter validation", () => {
  it("requires an HTTPS company website", () => {
    expect(
      validateCompanyInput({
        description: "",
        name: "Studio North",
        websiteUrl: "http://example.test",
      }),
    ).toEqual({ ok: false, message: "Use a valid HTTPS company website URL." });
    expect(
      validateCompanyInput({
        description: "Practice",
        name: "Studio North",
        websiteUrl: "https://example.test",
      }),
    ).toEqual({
      ok: true,
      value: {
        description: "Practice",
        name: "Studio North",
        websiteUrl: "https://example.test",
      },
    });
  });

  it("normalizes recruiter emails and bounds contact data", () => {
    expect(
      validateRecruiterInput({
        email: " PERSON@EXAMPLE.TEST ",
        fullName: "Person",
        phoneNumber: "",
      }),
    ).toEqual({
      ok: true,
      value: { email: "person@example.test", fullName: "Person", phoneNumber: null },
    });
    expect(
      validateRecruiterInput({ email: "not-an-email", fullName: "Person", phoneNumber: "" }),
    ).toMatchObject({ ok: false });
  });

  it("requires explicit reasons and valid future grant expiries", () => {
    expect(validateRequiredReason(" ")).toMatchObject({ ok: false });
    expect(validateRequiredReason("No longer authorized")).toEqual({
      ok: true,
      value: "No longer authorized",
    });
    expect(validateFutureOptionalTimestamp("")).toEqual({ ok: true, value: null });
    expect(validateFutureOptionalTimestamp("not-a-date")).toMatchObject({ ok: false });
  });
});
