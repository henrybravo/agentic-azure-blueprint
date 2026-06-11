"""Orchestrator FastAPI app — exposes POST /turn as an SSE stream.

The BFF proxies user turns here. The graph (graph.py) is a minimal LangGraph example;
replace its node(s) with your domain agent. State is persisted via the injected
checkpointer so multi-turn memory is resumable.
"""
import json
from typing import Any, Iterator

from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from graph import stream_turn


class TurnRequest(BaseModel):
    threadId: str
    message: str


def _sse(event: dict[str, Any]) -> bytes:
    return f"data: {json.dumps(event)}\n\n".encode("utf-8")


def create_app(*, checkpointer: Any | None = None) -> FastAPI:
    app = FastAPI(title="Agentic Azure Blueprint Orchestrator")

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "healthy"}

    @app.post("/turn")
    async def turn(body: TurnRequest) -> StreamingResponse:
        def _gen() -> Iterator[bytes]:
            for event in stream_turn(body.threadId, body.message, checkpointer=checkpointer):
                yield _sse(event)

        return StreamingResponse(_gen(), media_type="text/event-stream")

    return app
