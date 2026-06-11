# agentic-api (BFF)

FastAPI Backend-for-Frontend for the Agentic Azure Blueprint. The browser talks only to this
service; it validates identity (wire this) and proxies agent turns to the orchestrator over SSE.

```bash
uv pip install -e .
uv run fastapi dev main.py   # http://localhost:8080
uv run pytest
```

Replace the example `/api/chat` route in `app.py` with your domain API.
