"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { getPublicEnvironment } from "@/lib/environment";
import {
  validateCompanyInput,
  validateFutureOptionalTimestamp,
  validateRecruiterInput,
  validateRequiredReason,
} from "@/lib/companies/validation";
import { createSupabaseInvitationAdminClient } from "@/lib/supabase/admin";
import { getCurrentIdentity } from "@/lib/supabase/current-identity";
import { createServerSupabaseClient } from "@/lib/supabase/server";

const managerRoles = ["SUPER_ADMIN", "TNP_SECRETARY"] as const;
const staffRoles = [...managerRoles, "TNP_COORDINATOR"] as const;

type CompanyActionState =
  | "company-created"
  | "company-updated"
  | "company-archived"
  | "company-reactivated"
  | "recruiter-created"
  | "recruiter-updated"
  | "recruiter-archived"
  | "recruiter-reactivated"
  | "invitation-sent"
  | "invitation-failed"
  | "invitation-revoked"
  | "drive-granted"
  | "drive-revoked"
  | "error";

function value(formData: FormData, name: string): string {
  const formValue = formData.get(name);
  return typeof formValue === "string" ? formValue : "";
}

function companyPath(companyId: string, state: CompanyActionState): string {
  return `/tnp/companies/${encodeURIComponent(companyId)}?state=${state}`;
}

function fail(companyId: string): never {
  redirect(companyPath(companyId, "error"));
}

async function requireStaff() {
  const identity = await getCurrentIdentity();
  if (!identity || !staffRoles.includes(identity.role as (typeof staffRoles)[number])) {
    redirect("/account?error=tnp-company-access-required");
  }
  return identity;
}

async function requireManager() {
  const identity = await requireStaff();
  if (!managerRoles.includes(identity.role as (typeof managerRoles)[number])) {
    redirect("/account?error=tnp-company-manager-required");
  }
  return identity;
}

function refreshCompany(companyId: string) {
  revalidatePath("/tnp/companies");
  revalidatePath(`/tnp/companies/${companyId}`);
}

export async function createCompany(formData: FormData): Promise<void> {
  await requireStaff();
  const input = validateCompanyInput({
    name: value(formData, "name"),
    websiteUrl: value(formData, "websiteUrl"),
    description: value(formData, "description"),
  });
  if (!input.ok) redirect("/tnp/companies?state=error");

  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("create_company", {
    p_description: input.value.description,
    p_name: input.value.name,
    p_website_url: input.value.websiteUrl,
  });
  if (error || typeof data !== "string") redirect("/tnp/companies?state=error");
  refreshCompany(data);
  redirect(companyPath(data, "company-created"));
}

export async function updateCompany(formData: FormData): Promise<void> {
  await requireStaff();
  const companyId = value(formData, "companyId");
  const input = validateCompanyInput({
    name: value(formData, "name"),
    websiteUrl: value(formData, "websiteUrl"),
    description: value(formData, "description"),
  });
  if (!companyId || !input.ok) fail(companyId);

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("update_company", {
    p_company_id: companyId,
    p_description: input.value.description,
    p_name: input.value.name,
    p_website_url: input.value.websiteUrl,
  });
  if (error) fail(companyId);
  refreshCompany(companyId);
  redirect(companyPath(companyId, "company-updated"));
}

export async function setCompanyArchiveState(formData: FormData): Promise<void> {
  await requireManager();
  const companyId = value(formData, "companyId");
  const archived = value(formData, "archived") === "true";
  if (!companyId) fail(companyId);
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("set_company_archive_state", {
    p_company_id: companyId,
    p_is_archived: archived,
  });
  if (error) fail(companyId);
  refreshCompany(companyId);
  redirect(companyPath(companyId, archived ? "company-archived" : "company-reactivated"));
}

export async function createRecruiterContact(formData: FormData): Promise<void> {
  await requireStaff();
  const companyId = value(formData, "companyId");
  const input = validateRecruiterInput({
    fullName: value(formData, "fullName"),
    email: value(formData, "email"),
    phoneNumber: value(formData, "phoneNumber"),
  });
  if (!companyId || !input.ok) fail(companyId);
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("create_recruiter_contact", {
    p_company_id: companyId,
    p_email: input.value.email,
    p_full_name: input.value.fullName,
    p_phone_number: input.value.phoneNumber,
  });
  if (error) fail(companyId);
  refreshCompany(companyId);
  redirect(companyPath(companyId, "recruiter-created"));
}

export async function updateRecruiterContact(formData: FormData): Promise<void> {
  await requireStaff();
  const companyId = value(formData, "companyId");
  const recruiterId = value(formData, "recruiterId");
  const input = validateRecruiterInput({
    fullName: value(formData, "fullName"),
    email: value(formData, "email"),
    phoneNumber: value(formData, "phoneNumber"),
  });
  if (!companyId || !recruiterId || !input.ok) fail(companyId);
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("update_recruiter_contact", {
    p_email: input.value.email,
    p_full_name: input.value.fullName,
    p_phone_number: input.value.phoneNumber,
    p_recruiter_id: recruiterId,
  });
  if (error) fail(companyId);
  refreshCompany(companyId);
  redirect(companyPath(companyId, "recruiter-updated"));
}

export async function setRecruiterArchiveState(formData: FormData): Promise<void> {
  await requireManager();
  const companyId = value(formData, "companyId");
  const recruiterId = value(formData, "recruiterId");
  const archived = value(formData, "archived") === "true";
  if (!companyId || !recruiterId) fail(companyId);
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("set_recruiter_archive_state", {
    p_is_archived: archived,
    p_recruiter_id: recruiterId,
  });
  if (error) fail(companyId);
  refreshCompany(companyId);
  redirect(companyPath(companyId, archived ? "recruiter-archived" : "recruiter-reactivated"));
}

function invitationRedirectUrl(): string {
  const appUrl = getPublicEnvironment().appUrl;
  if (!appUrl) throw new Error("NEXT_PUBLIC_APP_URL is required to issue recruiter invitations.");
  return new URL("/auth/callback?next=%2Frecruiter", appUrl).toString();
}

async function issueRecruiterInvitation(formData: FormData, isReissue: boolean): Promise<void> {
  await requireManager();
  const companyId = value(formData, "companyId");
  const recruiterId = value(formData, "recruiterId");
  if (!companyId || !recruiterId) fail(companyId);
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .rpc("prepare_recruiter_invitation", {
      p_is_reissue: isReissue,
      p_recruiter_id: recruiterId,
    })
    .single();
  const invitation = data as { invitation_email?: unknown; invitation_id?: unknown } | null;
  if (
    error ||
    !invitation ||
    typeof invitation.invitation_id !== "string" ||
    typeof invitation.invitation_email !== "string"
  ) {
    fail(companyId);
  }

  try {
    const invitationAdmin = createSupabaseInvitationAdminClient();
    const { data: authData, error: inviteError } =
      await invitationAdmin.auth.admin.inviteUserByEmail(invitation.invitation_email, {
        data: { recruiter_invitation_id: invitation.invitation_id },
        redirectTo: invitationRedirectUrl(),
      });
    if (inviteError || !authData.user?.id) throw new Error("Invitation delivery failed.");

    const { error: sentError } = await supabase.rpc("mark_recruiter_invitation_sent", {
      p_auth_user_id: authData.user.id,
      p_invitation_id: invitation.invitation_id,
      p_is_reissue: isReissue,
    });
    if (sentError) throw new Error("Invitation could not be finalized.");
  } catch {
    await supabase.rpc("mark_recruiter_invitation_delivery_failed", {
      p_invitation_id: invitation.invitation_id,
    });
    refreshCompany(companyId);
    redirect(companyPath(companyId, "invitation-failed"));
  }

  refreshCompany(companyId);
  redirect(companyPath(companyId, "invitation-sent"));
}

export async function sendRecruiterInvitation(formData: FormData): Promise<void> {
  await issueRecruiterInvitation(formData, false);
}

export async function reissueRecruiterInvitation(formData: FormData): Promise<void> {
  await issueRecruiterInvitation(formData, true);
}

export async function revokeRecruiterInvitation(formData: FormData): Promise<void> {
  await requireManager();
  const companyId = value(formData, "companyId");
  const invitationId = value(formData, "invitationId");
  const reason = validateRequiredReason(value(formData, "reason"));
  if (!companyId || !invitationId || !reason.ok) fail(companyId);
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("revoke_recruiter_invitation", {
    p_invitation_id: invitationId,
    p_reason: reason.value,
  });
  if (error) fail(companyId);
  refreshCompany(companyId);
  redirect(companyPath(companyId, "invitation-revoked"));
}

export async function grantRecruiterDriveAccess(formData: FormData): Promise<void> {
  await requireManager();
  const companyId = value(formData, "companyId");
  const recruiterId = value(formData, "recruiterId");
  const driveId = value(formData, "driveId");
  const expiry = validateFutureOptionalTimestamp(value(formData, "expiresAt"));
  if (!companyId || !recruiterId || !driveId || !expiry.ok) fail(companyId);
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("grant_recruiter_drive_access", {
    p_drive_id: driveId,
    p_expires_at: expiry.value,
    p_recruiter_id: recruiterId,
  });
  if (error) fail(companyId);
  refreshCompany(companyId);
  redirect(companyPath(companyId, "drive-granted"));
}

export async function revokeRecruiterDriveAccess(formData: FormData): Promise<void> {
  await requireManager();
  const companyId = value(formData, "companyId");
  const recruiterId = value(formData, "recruiterId");
  const driveId = value(formData, "driveId");
  const reason = validateRequiredReason(value(formData, "reason"));
  if (!companyId || !recruiterId || !driveId || !reason.ok) fail(companyId);
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("revoke_recruiter_drive_access", {
    p_drive_id: driveId,
    p_reason: reason.value,
    p_recruiter_id: recruiterId,
  });
  if (error) fail(companyId);
  refreshCompany(companyId);
  redirect(companyPath(companyId, "drive-revoked"));
}
