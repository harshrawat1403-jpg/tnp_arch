import { NextResponse } from "next/server";

import { requireStudentIdentity } from "@/lib/student-profile/data";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ evidenceId: string }> },
): Promise<NextResponse> {
  const identity = await requireStudentIdentity();
  const { evidenceId } = await params;
  const supabase = await createServerSupabaseClient();
  const { data: evidence, error } = await supabase
    .from("student_skill_evidence")
    .select(
      "document:documents(storage_bucket, storage_path, owner_id, document_kind, is_archived)",
    )
    .eq("id", evidenceId)
    .maybeSingle();
  const document = evidence?.document as unknown as {
    document_kind: string;
    is_archived: boolean;
    owner_id: string;
    storage_bucket: string;
    storage_path: string;
  } | null;
  if (
    error ||
    !document ||
    document.owner_id !== identity.id ||
    document.document_kind !== "SKILL_EVIDENCE" ||
    document.is_archived
  ) {
    return new NextResponse("Evidence not found.", { status: 404 });
  }
  const { data: signed, error: signedError } = await supabase.storage
    .from(document.storage_bucket)
    .createSignedUrl(document.storage_path, 60);
  if (signedError || !signed)
    return new NextResponse("Evidence is temporarily unavailable.", { status: 503 });
  const response = NextResponse.redirect(signed.signedUrl);
  response.headers.set("Cache-Control", "private, no-store");
  return response;
}
