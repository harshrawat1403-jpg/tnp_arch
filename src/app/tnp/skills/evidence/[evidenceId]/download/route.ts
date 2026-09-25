import { NextResponse } from "next/server";

import { getCurrentIdentity } from "@/lib/supabase/current-identity";
import { createServerSupabaseClient } from "@/lib/supabase/server";

const staffRoles = ["SUPER_ADMIN", "TNP_SECRETARY", "TNP_COORDINATOR"] as const;

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ evidenceId: string }> },
): Promise<NextResponse> {
  const identity = await getCurrentIdentity();
  if (!identity || !staffRoles.includes(identity.role as (typeof staffRoles)[number])) {
    return new NextResponse("Evidence not found.", { status: 404 });
  }

  const { evidenceId } = await params;
  const supabase = await createServerSupabaseClient();
  const { data: evidence, error } = await supabase
    .from("student_skill_evidence")
    .select("document:documents(storage_bucket, storage_path, document_kind, is_archived)")
    .eq("id", evidenceId)
    .maybeSingle();
  const document = evidence?.document as unknown as {
    document_kind: string;
    is_archived: boolean;
    storage_bucket: string;
    storage_path: string;
  } | null;

  // Evidence and document metadata RLS derive coordinator scope from the reviewed
  // student. A missing relation therefore denies recruiter and out-of-scope access.
  if (error || !document || document.document_kind !== "SKILL_EVIDENCE" || document.is_archived) {
    return new NextResponse("Evidence not found.", { status: 404 });
  }

  const { data: signed, error: signedError } = await supabase.storage
    .from(document.storage_bucket)
    .createSignedUrl(document.storage_path, 60);
  if (signedError || !signed) {
    return new NextResponse("Evidence is temporarily unavailable.", { status: 503 });
  }

  const response = NextResponse.redirect(signed.signedUrl);
  response.headers.set("Cache-Control", "private, no-store");
  return response;
}
