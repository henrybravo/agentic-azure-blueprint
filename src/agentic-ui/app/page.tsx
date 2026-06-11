export default function Home() {
  return (
    <main>
      <h1>Agentic Azure Blueprint</h1>
      <p>
        This is the starter landing page. The browser talks to this Next.js app, which
        proxies agent turns server-side (<code>/api/chat</code>) to the FastAPI BFF
        (<code>agentic-api</code>) — kept internal — which in turn calls the LangGraph{" "}
        <code>orchestrator</code> over SSE.
      </p>
      <p>
        Replace this page with your product UI. Begin the spec-driven workflow with{" "}
        <code>apm run prd</code> (or run the prompts in <code>.github/prompts/</code>).
      </p>
    </main>
  );
}
