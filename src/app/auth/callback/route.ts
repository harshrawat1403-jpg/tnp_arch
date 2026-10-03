import { type NextRequest, NextResponse } from "next/server";

import { getSafeAppPath } from "@/lib/auth/redirect";
import { createServerSupabaseClient } from "@/lib/supabase/server";

function callbackRedirect(path: string, request: NextRequest): NextResponse {
  const response = NextResponse.redirect(new URL(path, request.url));
  response.headers.set("Cache-Control", "private, no-store");
  response.headers.set("Referrer-Policy", "no-referrer");
  return response;
}

export async function GET(request: NextRequest): Promise<NextResponse> {
  const code = request.nextUrl.searchParams.get("code");
  const next = getSafeAppPath(request.nextUrl.searchParams.get("next") ?? undefined);
  const tokenHash = request.nextUrl.searchParams.get("token_hash");
  const isRecruiterInvite =
    next === "/recruiter" && request.nextUrl.searchParams.get("type") === "invite";

  if (!code && !(isRecruiterInvite && tokenHash)) {
    return callbackRedirect("/login?error=invalid", request);
  }

  try {
    const supabase = await createServerSupabaseClient();
    // Admin invitations do not support PKCE. The invite email template points
    // here for server-side verification; ordinary PKCE callbacks keep their path.
    const { error } = code
      ? await supabase.auth.exchangeCodeForSession(code)
      : await supabase.auth.verifyOtp({ token_hash: tokenHash!, type: "invite" });

    if (error) {
      return callbackRedirect("/login?error=invalid", request);
    }

    if (next === "/student") {
      const { error: registrationError } = await supabase.rpc("complete_student_registration");

      if (registrationError) {
        return callbackRedirect("/register?state=invalid", request);
      }
    }

    if (next === "/recruiter") {
      const { error: completionError } = await supabase.rpc("complete_recruiter_invitation");

      if (completionError) {
        return callbackRedirect("/login?error=invalid", request);
      }

      return callbackRedirect("/recruiter/setup-password", request);
    }
  } catch {
    return callbackRedirect("/login?error=unavailable", request);
  }

  return callbackRedirect(next, request);
}
