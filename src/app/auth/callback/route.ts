import { type NextRequest, NextResponse } from "next/server";

import { getSafeAppPath } from "@/lib/auth/redirect";
import { createServerSupabaseClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest): Promise<NextResponse> {
  const code = request.nextUrl.searchParams.get("code");
  const next = getSafeAppPath(request.nextUrl.searchParams.get("next") ?? undefined);

  if (!code) {
    return NextResponse.redirect(new URL("/login?error=invalid", request.url));
  }

  try {
    const supabase = await createServerSupabaseClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);

    if (error) {
      return NextResponse.redirect(new URL("/login?error=invalid", request.url));
    }

    if (next === "/student") {
      const { error: registrationError } = await supabase.rpc("complete_student_registration");

      if (registrationError) {
        return NextResponse.redirect(new URL("/register?state=invalid", request.url));
      }
    }
  } catch {
    return NextResponse.redirect(new URL("/login?error=unavailable", request.url));
  }

  return NextResponse.redirect(new URL(next, request.url));
}
