// Matches [auth].minimum_password_length in supabase/config.toml. Supabase Auth
// remains authoritative if the deployed provider requires a stronger password.
export const minimumRecruiterPasswordLength = 6;

export function validateRecruiterPassword(password: unknown, confirmation: unknown): boolean {
  return (
    typeof password === "string" &&
    typeof confirmation === "string" &&
    password.length >= minimumRecruiterPasswordLength &&
    password === confirmation
  );
}
