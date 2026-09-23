"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { getCurrentIdentity } from "@/lib/supabase/current-identity";
import { createServerSupabaseClient } from "@/lib/supabase/server";

function formValue(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

async function requireSkillStaff() {
  const identity = await getCurrentIdentity();
  if (!identity || !["SUPER_ADMIN", "TNP_SECRETARY", "TNP_COORDINATOR"].includes(identity.role)) {
    redirect("/account?error=tnp-skill-access-required");
  }
  return identity;
}

function done(
  state:
    | "catalog-saved"
    | "catalog-updated"
    | "catalog-archived"
    | "catalog-reactivated"
    | "scope-saved"
    | "scope-removed"
    | "verified-skill-corrected"
    | "verified-skill-revoked"
    | "error"
    | "reviewed",
): never {
  redirect(`/tnp/skills?state=${state}`);
}

export async function reviewStudentSkill(formData: FormData): Promise<void> {
  await requireSkillStaff();
  const status = formValue(formData, "verificationStatus");
  const studentSkillId = formValue(formData, "studentSkillId");
  if (!studentSkillId || (status !== "VERIFIED" && status !== "REJECTED")) done("error");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("review_student_skill", {
    p_reviewer_note: formValue(formData, "reviewerNote") || null,
    p_student_skill_id: studentSkillId,
    p_verification_status: status,
  });
  if (error) done("error");
  revalidatePath("/tnp/skills");
  done("reviewed");
}

export async function createCatalogSkill(formData: FormData): Promise<void> {
  const identity = await requireSkillStaff();
  if (!["SUPER_ADMIN", "TNP_SECRETARY"].includes(identity.role)) done("error");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("create_skill_catalog_entry", {
    p_display_name: formValue(formData, "displayName"),
  });
  if (error) done("error");
  revalidatePath("/tnp/skills");
  done("catalog-saved");
}

async function requireCatalogManager() {
  const identity = await requireSkillStaff();
  if (!["SUPER_ADMIN", "TNP_SECRETARY"].includes(identity.role)) done("error");
  return identity;
}

export async function updateCatalogSkill(formData: FormData): Promise<void> {
  await requireCatalogManager();
  const skillId = formValue(formData, "skillId");
  const displayName = formValue(formData, "displayName").trim();
  if (!skillId || !displayName || displayName.length > 120) done("error");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("update_skill_catalog_entry", {
    p_display_name: displayName,
    p_skill_id: skillId,
  });
  if (error) done("error");
  revalidatePath("/tnp/skills");
  done("catalog-updated");
}

export async function archiveCatalogSkill(formData: FormData): Promise<void> {
  await requireCatalogManager();
  const skillId = formValue(formData, "skillId");
  if (!skillId || formValue(formData, "archiveConfirmation") !== "ARCHIVE") done("error");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("archive_skill_catalog_entry", { p_skill_id: skillId });
  if (error) done("error");
  revalidatePath("/tnp/skills");
  done("catalog-archived");
}

export async function reactivateCatalogSkill(formData: FormData): Promise<void> {
  await requireCatalogManager();
  const skillId = formValue(formData, "skillId");
  if (!skillId) done("error");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("reactivate_skill_catalog_entry", { p_skill_id: skillId });
  if (error) done("error");
  revalidatePath("/tnp/skills");
  done("catalog-reactivated");
}

export async function assignCoordinatorScope(formData: FormData): Promise<void> {
  await requireCatalogManager();
  const coordinatorId = formValue(formData, "coordinatorId");
  const course = formValue(formData, "course").trim();
  const batchYear = Number(formValue(formData, "batchYear"));
  if (!coordinatorId || !course || course.length > 120 || !Number.isInteger(batchYear))
    done("error");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("assign_coordinator_student_scope", {
    p_batch_year: batchYear,
    p_coordinator_id: coordinatorId,
    p_course: course,
  });
  if (error) done("error");
  revalidatePath("/tnp/skills");
  done("scope-saved");
}

export async function removeCoordinatorScope(formData: FormData): Promise<void> {
  await requireCatalogManager();
  const coordinatorId = formValue(formData, "coordinatorId");
  const course = formValue(formData, "course");
  const batchYear = Number(formValue(formData, "batchYear"));
  if (!coordinatorId || !course || !Number.isInteger(batchYear)) done("error");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("remove_coordinator_student_scope", {
    p_batch_year: batchYear,
    p_coordinator_id: coordinatorId,
    p_course: course,
  });
  if (error) done("error");
  revalidatePath("/tnp/skills");
  done("scope-removed");
}

export async function correctVerifiedStudentSkill(formData: FormData): Promise<void> {
  await requireCatalogManager();
  const studentSkillId = formValue(formData, "studentSkillId");
  const proficiencyLevel = Number(formValue(formData, "proficiencyLevel"));
  const reason = formValue(formData, "reason").trim();
  if (
    !studentSkillId ||
    !Number.isInteger(proficiencyLevel) ||
    proficiencyLevel < 1 ||
    proficiencyLevel > 4 ||
    !reason
  )
    done("error");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("correct_verified_student_skill", {
    p_proficiency_level: proficiencyLevel,
    p_reason: reason,
    p_student_skill_id: studentSkillId,
  });
  if (error) done("error");
  revalidatePath("/tnp/skills");
  done("verified-skill-corrected");
}

export async function revokeVerifiedStudentSkill(formData: FormData): Promise<void> {
  await requireCatalogManager();
  const studentSkillId = formValue(formData, "studentSkillId");
  const reason = formValue(formData, "reason").trim();
  if (!studentSkillId || !reason) done("error");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("revoke_verified_student_skill", {
    p_reason: reason,
    p_student_skill_id: studentSkillId,
  });
  if (error) done("error");
  revalidatePath("/tnp/skills");
  done("verified-skill-revoked");
}
