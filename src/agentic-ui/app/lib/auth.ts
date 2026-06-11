// Optional simple credential gate for the public UI — the fallback for when Entra ID
// sign-in is not available (e.g. the operator lacks directory permissions to create
// app registrations). The gate is ENABLED only when UI_AUTH_USERNAME and
// UI_AUTH_PASSWORD are configured; otherwise the UI stays open and Entra ID can be
// wired later to replace it. No credentials are hardcoded — they come from the
// environment.
//
// Uses Web Crypto (HMAC-SHA256) so the same helpers work in both the Edge middleware
// and Node route handlers.

export const SESSION_COOKIE = "ui_session";

function getConfig(): { username?: string; password?: string; secret: string } {
  const username = process.env.UI_AUTH_USERNAME;
  const password = process.env.UI_AUTH_PASSWORD;
  const secret = process.env.UI_AUTH_SECRET || password || "";
  return { username, password, secret };
}

/** The gate is active only when both a username and password are configured. */
export function authEnabled(): boolean {
  const { username, password } = getConfig();
  return Boolean(username && password);
}

function toBase64Url(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function sign(value: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value));
  return toBase64Url(sig);
}

/** Opaque, stateless session token bound to the configured user + secret. */
export async function issueSessionToken(): Promise<string> {
  const { username, secret } = getConfig();
  return sign(`${username}|authed`, secret);
}

export async function isValidSession(token: string | undefined): Promise<boolean> {
  if (!token) return false;
  const expected = await issueSessionToken();
  return timingSafeEqual(token, expected);
}

export function verifyCredentials(username: string, password: string): boolean {
  const cfg = getConfig();
  if (!cfg.username || !cfg.password) return false;
  return timingSafeEqual(username, cfg.username) && timingSafeEqual(password, cfg.password);
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
