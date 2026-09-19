import { describe, expect, it } from "vitest";

import { getStudentProfileCompleteness } from "./completeness";

describe("getStudentProfileCompleteness", () => {
  it("reports every required missing item explicitly", () => {
    expect(
      getStudentProfileCompleteness({
        activeResumeId: null,
        displayName: " ",
        hasAcademicRecord: false,
        phoneNumber: null,
        skills: [],
      }),
    ).toEqual({
      isComplete: false,
      missingItems: [
        "Full name",
        "Phone number",
        "At least one skill",
        "Academic record",
        "Resume",
      ],
    });
  });

  it("treats the approved required fields as complete", () => {
    expect(
      getStudentProfileCompleteness({
        activeResumeId: "resume-id",
        displayName: "Student One",
        hasAcademicRecord: true,
        phoneNumber: "+91 98765 43210",
        skills: ["AutoCAD"],
      }),
    ).toEqual({ isComplete: true, missingItems: [] });
  });
});
