"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { requireStudentIdentity } from "@/lib/student-profile/data";
import { createServerSupabaseClient } from "@/lib/supabase/server";
import {
  createSkillEvidencePath,
  validateProjectEvidence,
  validateProficiency,
} from "@/lib/student-skills/validation";
import { normalizeOriginalFilename, validateResumeFile } from "@/lib/student-profile/validation";

function value(formData: FormData, name: string): string {
  const formValue = formData.get(name);
  return typeof formValue === "string" ? formValue : "";
}

function returnToSkills(state: "error" | "saved" | "evidence-saved"): never {
  redirect(`/student/skills?state=${state}`);
}

export async function saveStudentSkill(formData: FormData): Promise<void> {
  await requireStudentIdentity();
  const proficiency = validateProficiency(value(formData, "proficiencyLevel"));
  const skillId = value(formData, "skillId");
  if (!proficiency.ok || !skillId) returnToSkills("error");

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("save_student_skill", {
    p_proficiency_level: proficiency.value,
    p_skill_id: skillId,
  });
  if (error) returnToSkills("error");
  revalidatePath("/student");
  revalidatePath("/student/profile");
  revalidatePath("/student/skills");
  returnToSkills("saved");
}

export async function addProjectEvidence(formData: FormData): Promise<void> {
  await requireStudentIdentity();
  const evidence = validateProjectEvidence({
    title: value(formData, "title"),
    description: value(formData, "description"),
    url: value(formData, "projectUrl"),
  });
  const studentSkillId = value(formData, "studentSkillId");
  if (!evidence.ok || !studentSkillId) returnToSkills("error");
  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.rpc("add_student_skill_project_evidence", {
    p_description: evidence.value.description,
    p_project_url: evidence.value.url,
    p_student_skill_id: studentSkillId,
    p_title: evidence.value.title,
  });
  if (error) returnToSkills("error");
  revalidatePath("/student/skills");
  returnToSkills("evidence-saved");
}

export async function uploadSkillEvidence(formData: FormData): Promise<void> {
  const identity = await requireStudentIdentity();
  const uploadedFile = formData.get("evidenceFile");
  const studentSkillId = value(formData, "studentSkillId");
  const title = value(formData, "title").trim();
  const description = value(formData, "description").trim();
  if (
    !(uploadedFile instanceof File) ||
    !studentSkillId ||
    !title ||
    title.length > 200 ||
    description.length > 2000
  ) {
    returnToSkills("error");
  }
  const file = await validateResumeFile(uploadedFile);
  if (!file.ok) returnToSkills("error");
  const storagePath = createSkillEvidencePath(identity.id, crypto.randomUUID());
  const supabase = await createServerSupabaseClient();
  const upload = await supabase.storage.from("skill-evidence").upload(storagePath, file.value, {
    cacheControl: "0",
    contentType: "application/pdf",
    upsert: false,
  });
  if (upload.error) returnToSkills("error");
  const { error } = await supabase.rpc("register_student_skill_evidence_document", {
    p_byte_size: file.value.size,
    p_description: description || null,
    p_original_filename: normalizeOriginalFilename(file.value.name),
    p_storage_path: storagePath,
    p_student_skill_id: studentSkillId,
    p_title: title,
  });
  if (error) {
    await supabase.storage.from("skill-evidence").remove([storagePath]);
    returnToSkills("error");
  }
  revalidatePath("/student/skills");
  returnToSkills("evidence-saved");
}
