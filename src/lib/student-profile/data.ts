import "server-only";

import { redirect } from "next/navigation";

import { type AuthenticatedIdentity } from "@/lib/auth/role";
import { getCurrentIdentity } from "@/lib/supabase/current-identity";
import { createServerSupabaseClient } from "@/lib/supabase/server";

import { getStudentProfileCompleteness, type StudentProfileCompleteness } from "./completeness";

export type StudentProfileData = {
  academicRecord: {
    activeBacklogCount: number;
    cgpa: number;
    verificationStatus: "PENDING" | "VERIFIED";
  } | null;
  completeness: StudentProfileCompleteness;
  identity: AuthenticatedIdentity;
  personalProfile: {
    phoneNumber: string | null;
    portfolioUrl: string | null;
    skills: string[];
    verificationStatus: "PENDING" | "VERIFIED";
  };
  resume: {
    id: string;
    originalFilename: string;
  } | null;
  roster: {
    batchYear: number;
    course: string;
  };
};

type StudentProfileRow = {
  phone_number: string | null;
  portfolio_url: string | null;
  roster_id: string;
  skills: string[];
  verification_status: "PENDING" | "VERIFIED";
};

type AcademicRecordRow = {
  active_backlog_count: number;
  cgpa: number | string;
  verification_status: "PENDING" | "VERIFIED";
};

type RosterRow = {
  batch_year: number;
  course: string;
};

type ResumeRow = {
  id: string;
  original_filename: string;
};

export async function requireStudentIdentity(): Promise<AuthenticatedIdentity> {
  const identity = await getCurrentIdentity();

  if (!identity) {
    redirect("/login?error=invalid&next=/student");
  }

  if (identity.role !== "STUDENT") {
    redirect("/account?error=student-access-required");
  }

  return identity;
}

export async function getStudentProfileData(): Promise<StudentProfileData> {
  const identity = await requireStudentIdentity();
  const supabase = await createServerSupabaseClient();
  const { data: personalProfileData, error: personalProfileError } = await supabase
    .from("student_profiles")
    .select("phone_number, portfolio_url, roster_id, skills, verification_status")
    .eq("user_id", identity.id)
    .maybeSingle();

  if (personalProfileError || !personalProfileData) {
    throw new Error("Unable to resolve the student profile.");
  }

  const personalProfile = personalProfileData as StudentProfileRow;
  const [academicResult, rosterResult, resumeResult] = await Promise.all([
    supabase
      .from("academic_records")
      .select("active_backlog_count, cgpa, verification_status")
      .eq("student_id", identity.id)
      .maybeSingle(),
    supabase
      .from("student_roster")
      .select("batch_year, course")
      .eq("id", personalProfile.roster_id)
      .maybeSingle(),
    supabase
      .from("documents")
      .select("id, original_filename")
      .eq("owner_id", identity.id)
      .eq("document_kind", "RESUME")
      .eq("is_archived", false)
      .maybeSingle(),
  ]);

  if (academicResult.error || rosterResult.error || resumeResult.error || !rosterResult.data) {
    throw new Error("Unable to resolve the student profile.");
  }

  const academicRow = academicResult.data as AcademicRecordRow | null;
  const roster = rosterResult.data as RosterRow;
  const resume = resumeResult.data as ResumeRow | null;

  const academicRecord = academicRow
    ? {
        activeBacklogCount: academicRow.active_backlog_count,
        cgpa: Number(academicRow.cgpa),
        verificationStatus: academicRow.verification_status,
      }
    : null;

  return {
    identity,
    personalProfile: {
      phoneNumber: personalProfile.phone_number,
      portfolioUrl: personalProfile.portfolio_url,
      skills: personalProfile.skills,
      verificationStatus: personalProfile.verification_status,
    },
    roster: { batchYear: roster.batch_year, course: roster.course },
    academicRecord,
    resume: resume ? { id: resume.id, originalFilename: resume.original_filename } : null,
    completeness: getStudentProfileCompleteness({
      activeResumeId: resume?.id ?? null,
      displayName: identity.displayName,
      hasAcademicRecord: academicRecord !== null,
      phoneNumber: personalProfile.phone_number,
      skills: personalProfile.skills,
    }),
  };
}
