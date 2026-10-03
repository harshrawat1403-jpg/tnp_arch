import Link from "next/link";
import { notFound } from "next/navigation";
import { DriveSummary, EligibilitySummary } from "@/components/drives/drive-summary";
import type { DriveDetail } from "@/lib/drives/data";
import { isUuid } from "@/lib/drives/validation";
import { requireStudentIdentity } from "@/lib/student-profile/data";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export default async function StudentDrivePage({
  params,
}: {
  params: Promise<{ driveId: string }>;
}) {
  await requireStudentIdentity();
  const { driveId } = await params;
  if (!isUuid(driveId)) notFound();
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase.rpc("student_drive_detail", { p_drive_id: driveId });
  if (error) throw new Error("Unable to load the opportunity.");
  if (!data) notFound();
  const drive = data as DriveDetail;
  return (
    <section className="student-page" aria-labelledby="opportunity-title">
      <p className="foundation__eyebrow">Published opportunity</p>
      <h1 id="opportunity-title">{drive.title}</h1>
      <Link href="/student/drives" className="text-link">
        All published drives
      </Link>
      <DriveSummary drive={drive} />
      {drive.eligibility ? <EligibilitySummary eligibility={drive.eligibility} /> : null}
      <p className="foundation__note">
        This is a current assessment only. Application submission is not part of Phase 7.
      </p>
    </section>
  );
}
