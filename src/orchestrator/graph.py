"""LangGraph example turn — replace with your domain agent.

A minimal single-node `StateGraph` builds the answer; `stream_turn` runs the graph and
yields ordered SSE-shaped events: zero or more `{"type": "delta", "text": ...}` then exactly
one terminal `{"type": "done", "answer": ..., "citations": [...]}`.

The model call is stubbed (offline-safe echo) so the shell runs with no Azure dependency.
Wire `_generate` to your model (via an APIM AI Gateway, using managed identity) when ready.
"""
from typing import Any, Iterator, TypedDict

from langgraph.graph import END, START, StateGraph


class TurnState(TypedDict, total=False):
    message: str
    answer: str
    citations: list[Any]


def _generate(message: str) -> str:
    """Produce the answer for a turn.

    TODO: replace this echo with a model call through the APIM AI Gateway:
        client = AzureOpenAI(azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"], ...)
        ... use DefaultAzureCredential / managed identity, never API keys ...
    """
    return f"You said: {message}"


def _answer_node(state: TurnState) -> TurnState:
    return {"answer": _generate(state["message"]), "citations": []}


def build_graph() -> Any:
    graph = StateGraph(TurnState)
    graph.add_node("answer", _answer_node)
    graph.add_edge(START, "answer")
    graph.add_edge("answer", END)
    return graph.compile()


_GRAPH = build_graph()


def stream_turn(
    thread_id: str,
    message: str,
    *,
    checkpointer: Any | None = None,
) -> Iterator[dict[str, Any]]:
    if not message or not message.strip():
        raise ValueError("Question must not be empty.")

    result: TurnState = _GRAPH.invoke({"message": message})
    answer = result.get("answer", "")
    citations = result.get("citations", [])

    # Stream the answer word-by-word so the BFF/UI can render tokens as they arrive.
    for token in answer.split(" "):
        yield {"type": "delta", "text": token + " "}
    yield {"type": "done", "answer": answer, "citations": citations}

    if checkpointer is not None:
        prior = checkpointer.get(thread_id) or {}
        turns = list(prior.get("turns", [])) if isinstance(prior, dict) else []
        turns.append({"message": message, "answer": answer, "citations": citations})
        checkpointer.put(thread_id, {"turns": turns})
