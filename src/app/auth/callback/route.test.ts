import { NextRequest } from "next/server";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ code: vi.fn(), otp: vi.fn(), rpc: vi.fn() }));
vi.mock("@/lib/auth/redirect", async () => import("../../../lib/auth/redirect"));
vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: async () => ({
    auth: { exchangeCodeForSession: mocks.code, verifyOtp: mocks.otp },
    rpc: mocks.rpc,
  }),
}));

import { GET } from "./route";

describe("recruiter invitation callback", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.code.mockResolvedValue({ error: null });
    mocks.otp.mockResolvedValue({ error: null });
    mocks.rpc.mockResolvedValue({ error: null });
  });

  it("verifies the provider invite then binds before redirecting to password setup", async () => {
    const response = await GET(
      new NextRequest(
        "http://localhost/auth/callback?token_hash=test-provider-hash&type=invite&next=/recruiter",
      ),
    );
    expect(mocks.otp).toHaveBeenCalledWith({ token_hash: "test-provider-hash", type: "invite" });
    expect(mocks.rpc).toHaveBeenCalledWith("complete_recruiter_invitation");
    expect(response.headers.get("location")).toBe("http://localhost/recruiter/setup-password");
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(response.headers.get("referrer-policy")).toBe("no-referrer");
    expect(mocks.code).not.toHaveBeenCalled();
  });

  it("keeps ordinary code exchange available", async () => {
    const response = await GET(
      new NextRequest("http://localhost/auth/callback?code=test-code&next=/account"),
    );
    expect(mocks.code).toHaveBeenCalledWith("test-code");
    expect(response.headers.get("location")).toBe("http://localhost/account");
    expect(mocks.otp).not.toHaveBeenCalled();
  });

  it("does not bind a failed provider verification or a replay", async () => {
    mocks.otp.mockResolvedValueOnce({ error: new Error("expired invite") });
    const response = await GET(
      new NextRequest(
        "http://localhost/auth/callback?token_hash=test-provider-hash&type=invite&next=/recruiter",
      ),
    );
    expect(response.headers.get("location")).toBe("http://localhost/login?error=invalid");
    expect(mocks.rpc).not.toHaveBeenCalled();
  });

  it("denies unsupported token types and unsafe targets before Auth exchange", async () => {
    for (const query of [
      "type=recovery&next=/recruiter",
      "type=invite&next=https://other.test",
      "type=invite&next=/student",
    ]) {
      const response = await GET(
        new NextRequest(`http://localhost/auth/callback?token_hash=test-provider-hash&${query}`),
      );
      expect(response.headers.get("location")).toBe("http://localhost/login?error=invalid");
    }
    expect(mocks.otp).not.toHaveBeenCalled();
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
});
