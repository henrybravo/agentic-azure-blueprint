"""BFF (agentic-api) FastAPI application factory — starter shell.

The browser only ever talks to this Backend-for-Frontend. It exposes health endpoints
and one example route that proxies a chat turn to the LangGraph orchestrator over SSE.

Replace the example with your domain API. Wire real Entra token validation + On-Behalf-Of
(see AGENTS.md "Production Checklist") before exposing protected data.
"""
import os
from typing import Any, Iterator

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

ORCHESTRATOR_URL = os.getenv("ORCHESTRATOR_URL", "http://localhost:8000")


class ChatRequest(BaseModel):
    """Example request body. Pydantic validates it — keep request models like this."""

    threadId: str
    message: str


def create_app() -> FastAPI:
    app = FastAPI(title="Agentic Azure Blueprint BFF")

    @app.get("/")
    async def root() -> dict[str, str]:
        return {"status": "healthy", "message": "Agentic BFF is running"}

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "healthy"}

    @app.post("/api/chat")
    async def chat(body: ChatRequest) -> StreamingResponse:
        # Validate before any downstream call. TODO: enforce identity + RBAC here.
        if not body.message or not body.message.strip():
            raise HTTPException(
                status_code=400,
                detail={"code": "empty_question", "message": "Question must not be empty."},
            )

        def _proxy() -> Iterator[bytes]:
            # Stream the orchestrator's SSE response straight through to the browser.
            url = f"{ORCHESTRATOR_URL}/turn"
            payload: dict[str, Any] = {"threadId": body.threadId, "message": body.message}
            with httpx.stream("POST", url, json=payload, timeout=60.0) as resp:
                for chunk in resp.iter_raw():
                    yield chunk

        return StreamingResponse(_proxy(), media_type="text/event-stream")

    return app
