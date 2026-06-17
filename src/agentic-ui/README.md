# agentic-ui

Next.js 16 / React 19 front end for the Agentic Azure Blueprint. The browser talks **only** to this
service; it proxies agent turns to the BFF server-side over SSE (`AGENT_API_URL` is a server-only
env var, so the BFF and orchestrator are never exposed to the browser).

```bash
npm install
npm run dev     # http://localhost:3000
npm run lint
npm run build
```

Requires **Node 20+** (the container image is `node:20-slim`). Set `AGENT_API_URL` in
`.env.local` (see `.env.local.example`) to point at the BFF; under Aspire this is wired for you.

Optional username/password gate: set `UI_AUTH_USERNAME` / `UI_AUTH_PASSWORD` to require sign-in
before any page or API call. Replace the example landing page in `app/page.tsx` with your domain UI.
