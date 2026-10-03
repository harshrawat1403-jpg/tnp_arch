import { describe, expect, it } from "vitest";
import { isUuid, parseEligiblePairs, parseRevision, validateDriveForm } from "./validation";

function form() {
  const data = new FormData();
  Object.entries({
    company_id: "73000000-0000-0000-0000-000000000001",
    title: "Architect",
    description: "An opportunity",
    drive_type: "PLACEMENT",
    application_deadline: "2030-01-01T10:00:00+05:30",
    minimum_cgpa: "0",
    maximum_active_backlogs: "0",
    eligible_pairs: "B.Arch | 2027\nBIM | 2028",
  }).forEach(([key, value]) => data.set(key, value));
  return data;
}
describe("drive form validation (not an eligibility engine)", () => {
  it("preserves exact pairs rather than a cross product", () => {
    expect(parseEligiblePairs(" B.Arch | 2027\r\nBIM | 2028")).toEqual({
      ok: true,
      value: [
        { course: "B.Arch", batch_year: 2027 },
        { course: "BIM", batch_year: 2028 },
      ],
    });
  });
  it.each([
    "",
    "B.Arch | 1999",
    "B.Arch | 2201",
    "B.Arch | 2027.5",
    "B.Arch",
    "B.Arch | 2027\n B.Arch | 2027",
    "x".repeat(121) + " | 2027",
  ])("rejects invalid pairs: %s", (value) => expect(parseEligiblePairs(value).ok).toBe(false));
  it("bounds pair count", () =>
    expect(
      parseEligiblePairs(Array.from({ length: 101 }, (_, i) => `Course ${i} | 2027`).join("\n")).ok,
    ).toBe(false));
  it.each(["0", "-1", "1.1", "1e2", "2147483648", ""])("rejects invalid revision %s", (value) =>
    expect(parseRevision(value)).toBeNull(),
  );
  it("accepts positive bounded revision and UUID", () => {
    expect(parseRevision("3")).toBe(3);
    expect(isUuid("invalid")).toBe(false);
  });
  it("preserves explicit timezone and zero thresholds", () => {
    const result = validateDriveForm(form());
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.value.application_deadline).toBe("2030-01-01T10:00:00+05:30");
      expect(result.value.minimum_cgpa).toBe(0);
    }
  });
  it.each([
    ["minimum_cgpa", ""],
    ["minimum_cgpa", "11"],
    ["minimum_cgpa", "NaN"],
    ["maximum_active_backlogs", "1.5"],
    ["maximum_active_backlogs", "51"],
    ["package_lpa", "-1"],
    ["package_lpa", "100000000"],
    ["application_deadline", "2030-01-01T10:00"],
    ["application_deadline", "invalid"],
    ["drive_type", "OTHER"],
    ["title", ""],
  ])("rejects malformed %s", (key, value) => {
    const input = form();
    input.set(key, value);
    expect(validateDriveForm(input).ok).toBe(false);
  });
  it("does not decide deadline availability in TypeScript", () => {
    const input = form();
    input.set("application_deadline", "2020-01-01T00:00:00Z");
    expect(validateDriveForm(input).ok).toBe(true);
  });
  it("preserves database timestamp microseconds", () => {
    const input = form();
    input.set("application_deadline", "2020-01-01T00:00:00.123456+00:00");
    const result = validateDriveForm(input);
    expect(result.ok && result.value.application_deadline).toBe("2020-01-01T00:00:00.123456+00:00");
  });
  it("rejects impossible calendar dates", () => {
    const input = form();
    input.set("application_deadline", "2030-02-31T00:00:00Z");
    expect(validateDriveForm(input).ok).toBe(false);
  });
});
