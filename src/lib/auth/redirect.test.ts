import { describe, expect, it } from "vitest";

import { getSafeAppPath } from "./redirect";

describe("getSafeAppPath", () => {
  it("accepts an application-relative path", () => {
    expect(getSafeAppPath("/account?tab=session")).toBe("/account?tab=session");
  });

  it("rejects external, protocol-relative, and malformed redirects", () => {
    expect(getSafeAppPath("https://attacker.example")).toBe("/account");
    expect(getSafeAppPath("//attacker.example")).toBe("/account");
    expect(getSafeAppPath("/\\attacker.example")).toBe("/account");
  });
});
