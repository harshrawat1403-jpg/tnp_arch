import { beforeEach, describe, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({ identity: vi.fn(), rpc: vi.fn() }));
vi.mock("server-only", () => ({}));
vi.mock("next/navigation", () => ({
  redirect: (path: string) => {
    throw new Error(path);
  },
}));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("@/lib/companies/validation", async () => import("../../../lib/companies/validation"));
vi.mock("@/lib/drives/validation", async () => import("../../../lib/drives/validation"));
vi.mock("@/lib/drives/data", async () => import("../../../lib/drives/data"));
vi.mock("@/lib/supabase/current-identity", () => ({ getCurrentIdentity: mocks.identity }));
vi.mock("@/lib/supabase/server", () => ({
  createServerSupabaseClient: async () => ({ rpc: mocks.rpc }),
}));
import { correctPublishedDrive, saveDraft, transitionDrive } from "./actions";

function form() {
  const data = new FormData();
  Object.entries({
    company_id: "73000000-0000-0000-0000-000000000001",
    drive_id: "74000000-0000-0000-0000-000000000001",
    revision: "3",
    title: "Architect",
    description: "An opportunity",
    drive_type: "PLACEMENT",
    application_deadline: "2030-01-01T10:00:00Z",
    minimum_cgpa: "0",
    maximum_active_backlogs: "0",
    eligible_pairs: "B.Arch | 2027",
    reason: "Internal reason",
    notice: "Student notice",
    next_status: "PUBLISHED",
  }).forEach(([key, value]) => data.set(key, value));
  return data;
}
describe("protected drive server actions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.identity.mockResolvedValue({ id: "actor", role: "TNP_SECRETARY" });
    mocks.rpc.mockResolvedValue({ data: "74000000-0000-0000-0000-000000000001", error: null });
  });
  it("unauthenticated mutations never reach database", async () => {
    mocks.identity.mockResolvedValue(null);
    await expect(saveDraft(form())).rejects.toThrow("/login");
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
  it.each(["STUDENT", "RECRUITER"])("rejects %s before database mutation", async (role) => {
    mocks.identity.mockResolvedValue({ role });
    await expect(saveDraft(form())).rejects.toThrow("access-required");
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
  it.each([correctPublishedDrive, transitionDrive])(
    "coordinator cannot invoke manager action",
    async (action) => {
      mocks.identity.mockResolvedValue({ role: "TNP_COORDINATOR" });
      await expect(action(form())).rejects.toThrow("access-required");
      expect(mocks.rpc).not.toHaveBeenCalled();
    },
  );
  it("allows coordinator draft editing but sends no browser-supplied actor", async () => {
    mocks.identity.mockResolvedValue({ role: "TNP_COORDINATOR" });
    await expect(saveDraft(form())).rejects.toThrow("saved=true");
    expect(mocks.rpc.mock.calls[0]?.[1]).not.toHaveProperty("p_actor_id");
  });
  it("rejects missing correction reason before RPC", async () => {
    const input = form();
    input.set("reason", "");
    await expect(correctPublishedDrive(input)).rejects.toThrow("required");
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
  it("rejects missing notice before RPC", async () => {
    const input = form();
    input.set("notice", "");
    await expect(correctPublishedDrive(input)).rejects.toThrow("required");
    expect(mocks.rpc).not.toHaveBeenCalled();
  });
  it("passes expected revision and both correction fields", async () => {
    await expect(correctPublishedDrive(form())).rejects.toThrow("saved=true");
    expect(mocks.rpc).toHaveBeenCalledWith(
      "correct_published_drive",
      expect.objectContaining({
        p_expected_revision: 3,
        p_reason: "Internal reason",
        p_notice: "Student notice",
      }),
    );
  });
  it("reports stale state safely without leaking SQL diagnostics", async () => {
    mocks.rpc.mockResolvedValue({ error: { code: "40001", message: "private SQL details" } });
    await expect(transitionDrive(form())).rejects.toThrow("Drive%20changed");
  });
});
