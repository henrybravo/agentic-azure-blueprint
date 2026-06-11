# orchestrator

LangGraph (Python) agent orchestrator for the Agentic Azure Blueprint. Exposes `POST /turn` as
an SSE stream. State is persisted via a swappable checkpointer (in-memory by default).

```bash
uv pip install -e .
uv run fastapi dev main.py   # http://localhost:8000
uv run pytest
```

Replace the example node in `graph.py` with your domain agent and wire `_generate` to your
model through the APIM AI Gateway (managed identity, no keys).
