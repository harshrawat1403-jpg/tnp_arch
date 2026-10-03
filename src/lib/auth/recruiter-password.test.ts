import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

import { minimumRecruiterPasswordLength, validateRecruiterPassword } from "./recruiter-password";

describe("recruiter password validation", () => {
  it("uses the configured Supabase minimum and preserves password whitespace", () => {
    const config = readFileSync("supabase/config.toml", "utf8");
    expect(Number(config.match(/^minimum_password_length\s*=\s*(\d+)/m)?.[1])).toBe(
      minimumRecruiterPasswordLength,
    );
    expect(validateRecruiterPassword("  abcd", "  abcd")).toBe(true);
  });

  it("rejects missing values, short passwords, and mismatched confirmation", () => {
    expect(validateRecruiterPassword(null, null)).toBe(false);
    expect(validateRecruiterPassword("abcde", "abcde")).toBe(false);
    expect(validateRecruiterPassword("abcdef", "abcdef ")).toBe(false);
  });
});
