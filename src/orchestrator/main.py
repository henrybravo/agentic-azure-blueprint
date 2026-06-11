"""Orchestrator entrypoint — uvicorn target (main:app).

The checkpointer is in-memory by default and swappable for a durable store (e.g. Cosmos
DB) when configured — keep agent state behind this seam so the graph stays storage-agnostic.
"""
from app import create_app
from checkpointer import build_checkpointer

app = create_app(checkpointer=build_checkpointer())
