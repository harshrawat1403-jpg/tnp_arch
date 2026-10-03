import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({ identity: vi.fn(), rpc: vi.fn(), invite: vi.fn() }));
vi.mock("next/navigation", () => ({
  redirect: (path: string) => {
    throw new Error(path);
  },
}));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("@/lib/environment", () => ({
  getPublicEnvironment: () => ({ appUrl: "http://127.0.0.1:3000" }),
}));
vi.mock("@/lib/companies/validation", async () => import("../../../lib/companies/validation"));
vi.mock("@/lib/supabase/current-identity", () => ({ getCurrentIdentity: mocks.identity }));
vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: async () => ({ rpc: mocks.rpc }),
}));
vi.mock("@/lib/supabase/admin", () => ({
  createSupabaseInvitationAdminClient: () => ({
    auth: { admin: { inviteUserByEmail: mocks.invite } },
  }),
}));

import { reissueRecruiterInvitation, sendRecruiterInvitation } from "./actions";

function form() {
  const data = new FormData();
  data.set("companyId", "company-id");
  data.set("recruiterId", "contact-id");
  return data;
}

describe("recruiter invitation hand-off failures", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.identity.mockResolvedValue({ id: "manager-id", role: "TNP_SECRETARY" });
    mocks.rpc.mockImplementation((name: string) =>
      name === "prepare_recruiter_invitation"
        ? {
            single: async () => ({
              data: { invitation_id: "invite-id", invitation_email: "invite@example.test" },
              error: null,
            }),
          }
        : Promise.resolve({ error: null }),
    );
    mocks.invite.mockResolvedValue({ data: { user: { id: "auth-id" } }, error: null });
  });

  it("does not mark provider success as delivery failure when finalization fails", async () => {
    mocks.rpc.mockImplementation((name: string) =>
      name === "prepare_recruiter_invitation"
        ? {
            single: async () => ({
              data: { invitation_id: "invite-id", invitation_email: "invite@example.test" },
              error: null,
            }),
          }
        : Promise.resolve({ error: new Error("DB finalization failed") }),
    );
    await expect(sendRecruiterInvitation(form())).rejects.toThrow(
      "invitation-finalization-pending",
    );
    expect(mocks.invite).toHaveBeenCalledOnce();
    expect(mocks.rpc.mock.calls.map(([name]) => name)).toEqual([
      "prepare_recruiter_invitation",
      "mark_recruiter_invitation_sent",
    ]);
  });

  it("preserves uncertain finalization after a transport exception", async () => {
    mocks.rpc.mockImplementation((name: string) =>
      name === "prepare_recruiter_invitation"
        ? {
            single: async () => ({
              data: { invitation_id: "invite-id", invitation_email: "invite@example.test" },
              error: null,
            }),
          }
        : Promise.reject(new Error("transport unavailable")),
    );
    await expect(sendRecruiterInvitation(form())).rejects.toThrow(
      "invitation-finalization-pending",
    );
    expect(
      mocks.rpc.mock.calls.some(([name]) => name === "mark_recruiter_invitation_delivery_failed"),
    ).toBe(false);
  });

  it("records provider failure separately", async () => {
    mocks.invite.mockResolvedValueOnce({
      data: { user: null },
      error: new Error("delivery failed"),
    });
    await expect(sendRecruiterInvitation(form())).rejects.toThrow("invitation-failed");
    expect(mocks.rpc.mock.calls.map(([name]) => name)).toEqual([
      "prepare_recruiter_invitation",
      "mark_recruiter_invitation_delivery_failed",
    ]);
  });

  it("reissues and finalizes the Auth user actually returned by Supabase", async () => {
    await expect(reissueRecruiterInvitation(form())).rejects.toThrow("invitation-sent");
    expect(mocks.rpc).toHaveBeenCalledWith("mark_recruiter_invitation_sent", {
      p_auth_user_id: "auth-id",
      p_invitation_id: "invite-id",
      p_is_reissue: true,
    });
  });

  it("denies coordinator and recruiter callers before any provider or database operation", async () => {
    for (const role of ["TNP_COORDINATOR", "RECRUITER", "STUDENT"]) {
      mocks.identity.mockResolvedValueOnce({ id: "caller-id", role });
      await expect(reissueRecruiterInvitation(form())).rejects.toThrow("required");
    }
    expect(mocks.rpc).not.toHaveBeenCalled();
    expect(mocks.invite).not.toHaveBeenCalled();
  });
});
