import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  identity: vi.fn(),
  recruiter: vi.fn(),
  updateUser: vi.fn(),
}));
vi.mock("next/navigation", () => ({
  redirect: (path: string) => {
    throw new Error(path);
  },
}));
vi.mock("@/lib/supabase/current-identity", () => ({ getCurrentIdentity: mocks.identity }));
vi.mock(
  "@/lib/auth/recruiter-password",
  async () => import("../../../lib/auth/recruiter-password"),
);
vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: async () => ({
    from: () => ({ select: () => ({ eq: () => ({ maybeSingle: mocks.recruiter }) }) }),
    auth: { updateUser: mocks.updateUser },
  }),
}));

import { setRecruiterPassword } from "./actions";

function form(password = "abcdef", confirmation = password) {
  const data = new FormData();
  data.set("password", password);
  data.set("confirmation", confirmation);
  return data;
}

describe("recruiter password action authorization", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.identity.mockResolvedValue({ id: "recruiter-id", role: "RECRUITER" });
    mocks.recruiter.mockResolvedValue({ data: { id: "contact-id" }, error: null });
    mocks.updateUser.mockResolvedValue({ error: null });
  });

  it("denies missing sessions and non-recruiter roles before updating Auth", async () => {
    mocks.identity.mockResolvedValueOnce(null);
    await expect(setRecruiterPassword(form())).rejects.toThrow("/login?");
    for (const role of ["STUDENT", "TNP_COORDINATOR", "TNP_SECRETARY", "SUPER_ADMIN"]) {
      mocks.identity.mockResolvedValueOnce({ id: "other-id", role });
      await expect(setRecruiterPassword(form())).rejects.toThrow("recruiter-access-required");
    }
    expect(mocks.updateUser).not.toHaveBeenCalled();
  });

  it("denies an inactive or inaccessible recruiter contact", async () => {
    mocks.recruiter.mockResolvedValueOnce({ data: null, error: null });
    await expect(setRecruiterPassword(form())).rejects.toThrow("recruiter-access-required");
    expect(mocks.updateUser).not.toHaveBeenCalled();
  });

  it("rejects invalid confirmation before sending a password to Auth", async () => {
    await expect(setRecruiterPassword(form("abcdef", "different"))).rejects.toThrow(
      "error=invalid",
    );
    expect(mocks.updateUser).not.toHaveBeenCalled();
  });

  it("uses only the caller-bound Auth update and redirects to the workspace", async () => {
    await expect(setRecruiterPassword(form())).rejects.toThrow("/recruiter");
    expect(mocks.updateUser).toHaveBeenCalledWith({ password: "abcdef" });
  });

  it("does not leak provider errors or passwords in redirects", async () => {
    mocks.updateUser.mockResolvedValueOnce({ error: new Error("sensitive provider detail") });
    await expect(setRecruiterPassword(form())).rejects.toThrow(
      "/recruiter/setup-password?error=provider",
    );
  });
});
