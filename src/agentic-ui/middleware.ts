import { NextRequest, NextResponse } from "next/server";

import { SESSION_COOKIE, authEnabled, isValidSession } from "@/app/lib/auth";

// Protect every route except Next internals and the login endpoints.
export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|login|api/login).*)"],
};

export async function middleware(req: NextRequest): Promise<NextResponse> {
  // Gate is off when no credentials are configured (e.g. Entra ID is used instead).
  if (!authEnabled()) return NextResponse.next();

  const token = req.cookies.get(SESSION_COOKIE)?.value;
  if (await isValidSession(token)) return NextResponse.next();

  // Unauthenticated: JSON 401 for API calls (incl. the BFF proxy), redirect for pages.
  if (req.nextUrl.pathname.startsWith("/api/")) {
    return NextResponse.json(
      { code: "unauthenticated", message: "Sign in required." },
      { status: 401 },
    );
  }

  const url = req.nextUrl.clone();
  url.pathname = "/login";
  url.search = "";
  return NextResponse.redirect(url);
}
