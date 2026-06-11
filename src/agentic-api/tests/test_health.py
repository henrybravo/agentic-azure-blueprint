"""Smoke tests for the BFF shell."""
from fastapi.testclient import TestClient

from app import create_app

client = TestClient(create_app())


def test_health() -> None:
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "healthy"}


def test_chat_rejects_empty_message() -> None:
    resp = client.post("/api/chat", json={"threadId": "t1", "message": "   "})
    assert resp.status_code == 400
    assert resp.json()["detail"]["code"] == "empty_question"
