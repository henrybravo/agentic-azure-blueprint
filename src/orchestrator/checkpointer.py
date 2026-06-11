"""Checkpointer seam — in-memory by default, swappable for a durable store.

Swap `_InMemoryCheckpointer` for a Cosmos DB (or other) implementation when
`AZURE_COSMOS_ENDPOINT` is configured, keeping the same get/put interface so the graph
stays storage-agnostic.
"""
import os
from typing import Any


class _InMemoryCheckpointer:
    def __init__(self) -> None:
        self._store: dict[str, Any] = {}

    def get(self, thread_id: str) -> Any:
        return self._store.get(thread_id)

    def put(self, thread_id: str, state: Any) -> None:
        self._store[thread_id] = state


def build_checkpointer() -> Any:
    # TODO: when AZURE_COSMOS_ENDPOINT is set, return a Cosmos-backed checkpointer
    # (managed identity via DefaultAzureCredential, partition by thread_id).
    if os.getenv("AZURE_COSMOS_ENDPOINT"):
        # Placeholder: fall back to in-memory until the durable store is wired.
        return _InMemoryCheckpointer()
    return _InMemoryCheckpointer()
