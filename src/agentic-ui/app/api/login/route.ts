import { NextRequest, NextResponse } from "next/server";

import { SESSION_COOKIE, issueSessionToken, verifyCredentials } from "@/app/lib/auth";

export const runtime = "nodejs";

export async function POST(req: NextRequest): Promise<NextResponse> {
  const form = await req.formData();
  const username = String(form.get("username") ?? "");
  const password = String(form.get("password") ?? "");

  const url = req.nextUrl.clone();
  url.search = "";

  if (!verifyCredentials(username, password)) {
    url.pathname = "/login";
    url.search = "?error=1";
    return NextResponse.redirect(url, { status: 303 });
  }

  const token = await issueSessionToken();
  url.pathname = "/";
  const res = NextResponse.redirect(url, { status: 303 });
  res.cookies.set(SESSION_COOKIE, token, {
    httpOnly: true,
    secure: req.nextUrl.protocol === "https:",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 8,
  });
  return res;
}
