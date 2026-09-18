import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";

import { getOptionalSupabaseEnvironment } from "./environment";

const protectedPaths = new Set(["/account"]);

function isProtectedPath(pathname: string): boolean {
  return protectedPaths.has(pathname);
}

function copyAuthCookies(source: NextResponse, target: NextResponse): NextResponse {
  source.cookies.getAll().forEach((cookie) => target.cookies.set(cookie));

  for (const headerName of ["cache-control", "expires", "pragma"]) {
    const value = source.headers.get(headerName);

    if (value) {
      target.headers.set(headerName, value);
    }
  }

  return target;
}

export async function updateAuthSession(request: NextRequest): Promise<NextResponse> {
  const environment = getOptionalSupabaseEnvironment();

  if (!environment) {
    return NextResponse.next({ request });
  }

  let response = NextResponse.next({ request });
  const supabase = createServerClient(environment.url.toString(), environment.publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options),
        );
      },
    },
  });

  const { data: claimsData } = await supabase.auth.getClaims();

  if (!isProtectedPath(request.nextUrl.pathname) || typeof claimsData?.claims?.sub === "string") {
    return response;
  }

  const loginUrl = request.nextUrl.clone();
  loginUrl.pathname = "/login";
  loginUrl.search = "";
  loginUrl.searchParams.set("next", request.nextUrl.pathname);

  return copyAuthCookies(response, NextResponse.redirect(loginUrl));
}
