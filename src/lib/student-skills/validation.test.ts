import { describe, expect, it } from "vitest";

import { validateProficiency, validateProjectEvidence } from "./validation";

describe("student skill validation", () => {
  it("uses only the approved proficiency range", () => {
    expect(validateProficiency("1")).toEqual({ ok: true, value: 1 });
    expect(validateProficiency("4")).toEqual({ ok: true, value: 4 });
    expect(validateProficiency("5")).toEqual({
      ok: false,
      message: "Choose a proficiency level from 1 to 4.",
    });
  });

  it("requires HTTPS project evidence", () => {
    expect(
      validateProjectEvidence({ title: "Model", description: "", url: "http://example.test" }),
    ).toEqual({
      ok: false,
      message: "Use an HTTPS project URL.",
    });
    expect(
      validateProjectEvidence({
        title: "Model",
        description: "Course work",
        url: "https://example.test/project",
      }),
    ).toEqual({
      ok: true,
      value: { title: "Model", description: "Course work", url: "https://example.test/project" },
    });
  });
});
