import { NextRequest } from "next/server";

// Server-side proxy: the browser calls THIS route, never the BFF directly.
// The BFF (agentic-api) has internal-only ingress, so it is reachable solely
// from inside the Container Apps environment — i.e. only via this proxy.
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const AGENT_API_URL = process.env.AGENT_API_URL;

export async function POST(req: NextRequest): Promise<Response> {
  if (!AGENT_API_URL) {
    return Response.json(
      { code: "config_error", message: "AGENT_API_URL is not configured." },
      { status: 500 },
    );
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return Response.json(
      { code: "invalid_body", message: "Request body must be valid JSON." },
      { status: 400 },
    );
  }

  let upstream: Response;
  try {
    upstream = await fetch(`${AGENT_API_URL}/api/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch (err) {
    console.error("BFF proxy request failed:", err);
    return Response.json(
      { code: "upstream_unreachable", message: "Could not reach the BFF." },
      { status: 502 },
    );
  }

  // Pass non-OK responses (e.g. validation errors) through unchanged.
  if (!upstream.ok || !upstream.body) {
    const detail = await upstream.text().catch(() => "");
    return new Response(detail || JSON.stringify({ code: "upstream_error" }), {
      status: upstream.status || 502,
      headers: {
        "Content-Type": upstream.headers.get("content-type") ?? "application/json",
      },
    });
  }

  // Relay the SSE stream straight through to the browser.
  return new Response(upstream.body, {
    status: 200,
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
    },
  });
}
