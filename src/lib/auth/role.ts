export const applicationRoles = [
  "SUPER_ADMIN",
  "TNP_SECRETARY",
  "TNP_COORDINATOR",
  "STUDENT",
  "RECRUITER",
] as const;

export type ApplicationRole = (typeof applicationRoles)[number];

export type AuthenticatedIdentity = {
  displayName: string;
  id: string;
  role: ApplicationRole;
};

type ProfileRecord = {
  display_name?: unknown;
  id?: unknown;
  is_active?: unknown;
  role?: unknown;
};

export function parseApplicationRole(value: unknown): ApplicationRole | null {
  return typeof value === "string" && applicationRoles.includes(value as ApplicationRole)
    ? (value as ApplicationRole)
    : null;
}

export function resolveAuthenticatedIdentity(
  value: unknown,
  authenticatedUserId: string,
): AuthenticatedIdentity | null {
  if (!value || typeof value !== "object") {
    return null;
  }

  const profile = value as ProfileRecord;
  const role = parseApplicationRole(profile.role);

  if (profile.id !== authenticatedUserId || profile.is_active !== true || !role) {
    return null;
  }

  return {
    id: authenticatedUserId,
    role,
    displayName:
      typeof profile.display_name === "string" && profile.display_name.trim()
        ? profile.display_name.trim()
        : "Account holder",
  };
}
