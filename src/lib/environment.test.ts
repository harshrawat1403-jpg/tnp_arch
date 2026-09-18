import { describe, expect, it } from "vitest";

import { validatePublicEnvironment } from "./environment";

describe("validatePublicEnvironment", () => {
  it("accepts an omitted application URL in development", () => {
    expect(validatePublicEnvironment({ nodeEnv: "development" })).toEqual({
      nodeEnv: "development",
    });
  });

  it("accepts an absolute HTTPS application URL", () => {
    expect(
      validatePublicEnvironment({
        appUrl: "https://tnp.example.edu",
        nodeEnv: "production",
      }).appUrl?.toString(),
    ).toBe("https://tnp.example.edu/");
  });

  it("rejects an invalid application URL", () => {
    expect(() =>
      validatePublicEnvironment({ appUrl: "tnp.example.edu", nodeEnv: "production" }),
    ).toThrow("NEXT_PUBLIC_APP_URL must be an absolute HTTP(S) URL.");
  });

  it("rejects an unsupported environment", () => {
    expect(() => validatePublicEnvironment({ nodeEnv: "preview" })).toThrow(
      "NODE_ENV must be development, test, or production.",
    );
  });
});
