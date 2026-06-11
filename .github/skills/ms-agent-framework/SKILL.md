---
name: ms-agent-framework
description: Add Microsoft Agent Framework to a Python FastAPI application. Use this skill when adding AI agent capabilities using Azure OpenAI and the agent-framework package to a Python backend.
license: MIT
metadata:
  author: agentic-shell
  version: "1.0"
compatibility: Requires Python 3.11+, FastAPI, and Azure OpenAI access
---

# Microsoft Agent Framework Integration

This skill helps you integrate the Microsoft Agent Framework into a Python FastAPI application for building AI agents powered by Azure OpenAI.

## When to Use

- Adding AI agent capabilities to a Python backend
- Building conversational AI with Azure OpenAI
- Creating agents that can use tools and follow instructions
- Setting up the backend for AG-UI protocol support

## Prerequisites

- Python 3.11 or higher
- An Azure OpenAI resource with a deployed model
- Azure CLI authenticated (`az login`)

## Step-by-Step Instructions

### 1. Install Dependencies

Add these dependencies to your `pyproject.toml`:

```toml
[project]
dependencies = [
    "agent-framework-ag-ui>=1.0.0b251120",
    "fastapi>=0.115.0",
    "uvicorn>=0.32.0",
]
```

Then install with:

```bash
cd src/agentic-api
uv pip install -e .
```

### 2. Configure Environment Variables

Create a `.env` file or set these environment variables:

```bash
AZURE_OPENAI_ENDPOINT=https://<your-resource>.openai.azure.com/
AZURE_OPENAI_DEPLOYMENT_NAME=<your-deployment-name>
```

### 3. Update main.py

Replace or update your `main.py` with the agent framework setup:

```python
import contextlib
import logging
import os

import fastapi
import telemetry

from agent_framework import ChatAgent
from agent_framework.azure import AzureOpenAIChatClient
from agent_framework_ag_ui import add_agent_framework_fastapi_endpoint
from azure.identity import AzureCliCredential

# Read required configuration
endpoint = os.environ.get("AZURE_OPENAI_ENDPOINT")
deployment_name = os.environ.get("AZURE_OPENAI_DEPLOYMENT_NAME")

if not endpoint:
    raise ValueError("AZURE_OPENAI_ENDPOINT environment variable is required")
if not deployment_name:
    raise ValueError("AZURE_OPENAI_DEPLOYMENT_NAME environment variable is required")

# Create the Azure OpenAI chat client with managed identity
chat_client = AzureOpenAIChatClient(
    credential=AzureCliCredential(),
    endpoint=endpoint,
    deployment_name=deployment_name,    
)

# Create the AI agent
agent = ChatAgent(
    name="AGUIAssistant",
    instructions="You are a helpful assistant.",
    chat_client=chat_client,
)

@contextlib.asynccontextmanager
async def lifespan(app: fastapi.FastAPI):
    telemetry.configure_opentelemetry()
    yield

app = fastapi.FastAPI(lifespan=lifespan)

# Register the AG-UI endpoint at the root
add_agent_framework_fastapi_endpoint(app, agent, "/")

logger = logging.getLogger(__name__)
```

### 4. Adding Tools to Your Agent

Agents can use tools to perform actions. Define tools as Python functions:

```python
from agent_framework import tool

@tool
def get_weather(location: str) -> str:
    """Get the current weather for a location."""
    # Implement weather lookup
    return f"The weather in {location} is sunny, 72°F"

@tool
def search_documents(query: str) -> list[str]:
    """Search internal documents for relevant information."""
    # Implement document search
    return ["Result 1", "Result 2"]

# Add tools to the agent
agent = ChatAgent(
    name="AGUIAssistant",
    instructions="You are a helpful assistant with access to weather and document search.",
    chat_client=chat_client,
    tools=[get_weather, search_documents],
)
```

### 5. Customizing Agent Instructions

Provide detailed instructions for your agent's behavior:

```python
agent = ChatAgent(
    name="AGUIAssistant",
    instructions="""You are a helpful assistant for Contoso Inc.

Your responsibilities:
- Answer questions about company policies
- Help employees find information
- Assist with common HR requests

Guidelines:
- Be professional and concise
- If you don't know something, say so
- Always verify sensitive information before sharing
""",
    chat_client=chat_client,
)
```

## Running Locally

```bash
cd src/agentic-api
uv run fastapi dev main.py
```

The agent will be available at `http://localhost:8080/`

## Azure Deployment

The agent framework works with Azure Managed Identity. In production:

1. Use `DefaultAzureCredential` instead of `AzureCliCredential`
2. Ensure your Container App has the `Cognitive Services User` role on your Azure OpenAI resource

```python
from azure.identity import DefaultAzureCredential

chat_client = AzureOpenAIChatClient(
    credential=DefaultAzureCredential(),
    endpoint=endpoint,
    deployment_name=deployment_name,    
)
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `AZURE_OPENAI_ENDPOINT not set` | Create `.env` file with your endpoint |
| `DefaultAzureCredential failed` | Run `az login` locally |
| `429 Too Many Requests` | Wait 1 min or increase Azure OpenAI quota |
| `Model not found` | Verify deployment name matches exactly |

## Related Skills

- Use the `ag-ui-integration` skill to connect a frontend to this agent
