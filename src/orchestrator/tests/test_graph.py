"""Tests for the orchestrator example graph."""
import pytest

from checkpointer import build_checkpointer
from graph import stream_turn


def test_stream_turn_emits_delta_then_done() -> None:
    events = list(stream_turn("t1", "hello world"))
    assert events[-1]["type"] == "done"
    assert events[-1]["answer"].startswith("You said:")
    assert any(e["type"] == "delta" for e in events[:-1])


def test_stream_turn_rejects_empty() -> None:
    with pytest.raises(ValueError):
        list(stream_turn("t1", "   "))


def test_checkpointer_persists_turn() -> None:
    cp = build_checkpointer()
    list(stream_turn("t1", "hi", checkpointer=cp))
    assert len(cp.get("t1")["turns"]) == 1
