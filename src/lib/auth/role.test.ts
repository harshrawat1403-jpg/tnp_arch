import { describe, expect, it } from "vitest";

import { applicationRoles, parseApplicationRole, resolveAuthenticatedIdentity } from "./role";

describe("role resolution", () => {
  it("recognizes every frozen application role", () => {
    for (const role of applicationRoles) {
      expect(parseApplicationRole(role)).toBe(role);
    }
  });

  it("rejects unrecognized roles", () => {
    expect(parseApplicationRole("ADMIN")).toBeNull();
    expect(parseApplicationRole(undefined)).toBeNull();
  });

  it("resolves only an active profile belonging to the authenticated user", () => {
    expect(
      resolveAuthenticatedIdentity(
        {
          id: "user-1",
          display_name: "Student One",
          is_active: true,
          role: "STUDENT",
        },
        "user-1",
      ),
    ).toEqual({
      id: "user-1",
      displayName: "Student One",
      role: "STUDENT",
    });

    expect(
      resolveAuthenticatedIdentity(
        { id: "another-user", display_name: "Forged", is_active: true, role: "SUPER_ADMIN" },
        "user-1",
      ),
    ).toBeNull();

    expect(
      resolveAuthenticatedIdentity(
        { id: "user-1", display_name: "Inactive", is_active: false, role: "STUDENT" },
        "user-1",
      ),
    ).toBeNull();
  });
});
