import { NextResponse } from "next/server";

import { createServerSupabaseClient } from "@/lib/supabase/server";
import { getStudentProfileData } from "@/lib/student-profile/data";

export async function GET(): Promise<NextResponse> {
  const profile = await getStudentProfileData();

  if (!profile.resume) {
    return new NextResponse("Resume not found.", { status: 404 });
  }

  const supabase = await createServerSupabaseClient();
  const { data: document, error: documentError } = await supabase
    .from("documents")
    .select("storage_bucket, storage_path")
    .eq("id", profile.resume.id)
    .eq("owner_id", profile.identity.id)
    .eq("document_kind", "RESUME")
    .eq("is_archived", false)
    .maybeSingle();

  if (documentError || !document) {
    return new NextResponse("Resume not found.", { status: 404 });
  }

  const { data: signedUrl, error: signedUrlError } = await supabase.storage
    .from(document.storage_bucket)
    .createSignedUrl(document.storage_path, 60);

  if (signedUrlError || !signedUrl) {
    return new NextResponse("Resume is temporarily unavailable.", { status: 503 });
  }

  const response = NextResponse.redirect(signedUrl.signedUrl);
  response.headers.set("Cache-Control", "private, no-store");
  return response;
}
