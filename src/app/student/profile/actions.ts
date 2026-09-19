"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { requireStudentIdentity } from "@/lib/student-profile/data";
import {
  createResumePath,
  normalizeOriginalFilename,
  validateAcademicInput,
  validatePersonalProfileInput,
  validateResumeFile,
} from "@/lib/student-profile/validation";

function profilePath(
  state: "academic-saved" | "error" | "personal-saved" | "resume-uploaded",
): string {
  return `/student/profile?state=${state}`;
}

function getFormValue(formData: FormData, name: string): string {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

export async function updatePersonalProfile(formData: FormData): Promise<void> {
  const identity = await requireStudentIdentity();
  const input = validatePersonalProfileInput({
    displayName: getFormValue(formData, "displayName"),
    phoneNumber: getFormValue(formData, "phoneNumber"),
    portfolioUrl: getFormValue(formData, "portfolioUrl"),
    skills: getFormValue(formData, "skills"),
  });

  if (!input.ok) {
    redirect(profilePath("error"));
  }

  const supabase = await createServerSupabaseClient();
  const profileResult = await supabase
    .from("profiles")
    .update({ display_name: input.value.displayName })
    .eq("id", identity.id);

  if (profileResult.error) {
    redirect(profilePath("error"));
  }

  const studentProfileResult = await supabase
    .from("student_profiles")
    .update({
      phone_number: input.value.phoneNumber,
      portfolio_url: input.value.portfolioUrl,
      skills: input.value.skills,
    })
    .eq("user_id", identity.id);

  if (studentProfileResult.error) {
    redirect(profilePath("error"));
  }

  revalidatePath("/student");
  revalidatePath("/student/profile");
  redirect(profilePath("personal-saved"));
}

export async function saveAcademicRecord(formData: FormData): Promise<void> {
  await requireStudentIdentity();
  const input = validateAcademicInput({
    cgpa: getFormValue(formData, "cgpa"),
    activeBacklogCount: getFormValue(formData, "activeBacklogCount"),
  });

  if (!input.ok) {
    redirect(profilePath("error"));
  }

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("save_student_academic_record", {
    p_active_backlog_count: input.value.activeBacklogCount,
    p_cgpa: input.value.cgpa,
  });

  if (error) {
    redirect(profilePath("error"));
  }

  revalidatePath("/student");
  revalidatePath("/student/profile");
  redirect(profilePath("academic-saved"));
}

export async function uploadResume(formData: FormData): Promise<void> {
  const identity = await requireStudentIdentity();
  const uploadedFile = formData.get("resume");

  if (!(uploadedFile instanceof File)) {
    redirect(profilePath("error"));
  }

  const file = await validateResumeFile(uploadedFile);

  if (!file.ok) {
    redirect(profilePath("error"));
  }

  const path = createResumePath(identity.id, crypto.randomUUID());

  if (!path.ok) {
    redirect(profilePath("error"));
  }

  const supabase = await createServerSupabaseClient();
  const uploadResult = await supabase.storage.from("resumes").upload(path.value, file.value, {
    cacheControl: "0",
    contentType: "application/pdf",
    upsert: false,
  });

  if (uploadResult.error) {
    redirect(profilePath("error"));
  }

  const { error: registrationError } = await supabase.rpc("replace_student_resume", {
    p_byte_size: file.value.size,
    p_original_filename: normalizeOriginalFilename(file.value.name),
    p_storage_path: path.value,
  });

  if (registrationError) {
    await supabase.storage.from("resumes").remove([path.value]);
    redirect(profilePath("error"));
  }

  revalidatePath("/student");
  revalidatePath("/student/profile");
  redirect(profilePath("resume-uploaded"));
}
