import { describe, expect, it } from "vitest";

import { validateSupabaseAdminEnvironment, validateSupabaseEnvironment } from "./environment";

describe("validateSupabaseEnvironment", () => {
  it("accepts browser-safe Supabase connection details", () => {
    expect(
      validateSupabaseEnvironment({
        url: "https://project.supabase.co",
        publishableKey: "sb_publishable_example",
      }),
    ).toMatchObject({
      publishableKey: "sb_publishable_example",
      url: new URL("https://project.supabase.co"),
    });
  });

  it("rejects absent, malformed, or non-HTTP(S) connection details", () => {
    expect(() => validateSupabaseEnvironment({ publishableKey: "key" })).toThrow(
      "NEXT_PUBLIC_SUPABASE_URL",
    );
    expect(() =>
      validateSupabaseEnvironment({ url: "postgres://database", publishableKey: "key" }),
    ).toThrow("NEXT_PUBLIC_SUPABASE_URL must use HTTP or HTTPS.");
    expect(() => validateSupabaseEnvironment({ url: "https://project.test" })).toThrow(
      "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
    );
  });
});

describe("validateSupabaseAdminEnvironment", () => {
  it("requires a server-only secret separate from the browser key", () => {
    expect(
      validateSupabaseAdminEnvironment({
        url: "https://project.supabase.co",
        publishableKey: "sb_publishable_example",
        secretKey: "sb_secret_example",
      }),
    ).toMatchObject({ secretKey: "sb_secret_example" });
    expect(() =>
      validateSupabaseAdminEnvironment({
        url: "https://project.supabase.co",
        publishableKey: "sb_publishable_example",
        secretKey: "sb_publishable_not_secret",
      }),
    ).toThrow("server-only");
  });
});
