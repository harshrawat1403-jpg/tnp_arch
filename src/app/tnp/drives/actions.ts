"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { validateRequiredReason } from "@/lib/companies/validation";
import { requireDriveStaff } from "@/lib/drives/data";
import {
  isUuid,
  parseRevision,
  validateDriveForm,
  DRIVE_STATUSES,
  type DriveStatus,
} from "@/lib/drives/validation";
import { createServerSupabaseClient } from "@/lib/supabase/server";

function value(form: FormData, name: string): string {
  const raw = form.get(name);
  return typeof raw === "string" ? raw : "";
}
function fail(id: string, message: string): never {
  const path = isUuid(id) ? `/tnp/drives/${id}` : "/tnp/drives/new";
  redirect(`${path}?error=${encodeURIComponent(message)}`);
}
function refresh(id: string) {
  revalidatePath("/tnp/drives");
  revalidatePath(`/tnp/drives/${id}`);
  revalidatePath("/student/drives");
  revalidatePath(`/student/drives/${id}`);
}
function operationError(code?: string): string {
  return code === "40001"
    ? "Drive changed. Reload and review the current revision before trying again."
    : "Operation denied. Check the drive state, deadline, company, criteria and required correction fields.";
}

export async function saveDraft(form: FormData): Promise<void> {
  await requireDriveStaff();
  const id = value(form, "drive_id");
  const revision = parseRevision(value(form, "revision"));
  const input = validateDriveForm(form);
  if (!input.ok) fail(id, input.message);
  if (id && (!isUuid(id) || !revision)) fail(id, "Invalid drive or revision.");
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("save_drive_draft", {
    p_content: input.value,
    p_drive_id: id || null,
    p_expected_revision: revision,
  });
  if (error || typeof data !== "string") fail(id, operationError(error?.code));
  refresh(data);
  redirect(`/tnp/drives/${data}?saved=true`);
}

export async function correctPublishedDrive(form: FormData): Promise<void> {
  await requireDriveStaff(true);
  const id = value(form, "drive_id");
  const revision = parseRevision(value(form, "revision"));
  const input = validateDriveForm(form);
  const reason = validateRequiredReason(value(form, "reason"));
  const notice = validateRequiredReason(value(form, "notice"));
  if (!input.ok) fail(id, input.message);
  if (!isUuid(id) || !revision || !reason.ok || !notice.ok)
    fail(id, "A current revision, internal reason and student-facing notice are required.");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("correct_published_drive", {
    p_drive_id: id,
    p_expected_revision: revision,
    p_content: input.value,
    p_reason: reason.value,
    p_notice: notice.value,
  });
  if (error) fail(id, operationError(error.code));
  refresh(id);
  redirect(`/tnp/drives/${id}?saved=true`);
}

export async function transitionDrive(form: FormData): Promise<void> {
  await requireDriveStaff(true);
  const id = value(form, "drive_id");
  const revision = parseRevision(value(form, "revision"));
  const status = value(form, "next_status");
  if (!isUuid(id) || !revision || !DRIVE_STATUSES.includes(status as DriveStatus))
    fail(id, "Invalid lifecycle request.");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("transition_drive", {
    p_drive_id: id,
    p_expected_revision: revision,
    p_next_status: status,
  });
  if (error) fail(id, operationError(error.code));
  refresh(id);
  revalidatePath("/tnp/companies");
  redirect(`/tnp/drives/${id}?saved=true`);
}
