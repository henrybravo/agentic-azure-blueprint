# AGENTS.md

AI coding agent instructions for the Agentic Azure Blueprint.

## Overview

| Aspect | Details |
|--------|---------|
| **Stack** | Python 3.11+ FastAPI BFF + LangGraph orchestrator, Next.js 16/React 19 frontend |
| **Infra** | Azure Container Apps, Azure AI Foundry (OpenAI), Aspire orchestration, managed identity |
| **Status** | Starter shell — spec2cloud spec-driven. Use the SDD workflow + skills to build features |
| **Auth** | Azure Managed Identity (no secrets in code); Entra/MSAL/OBO is the documented pattern |

## Quick Start

```bash
# Recommended: Aspire orchestration (api + orchestrator + ui + dashboard)
dotnet run apphost.cs
# BFF: localhost:8080 | Orchestrator: localhost:8000 | UI: localhost:3000 | Dashboard: localhost:15888

# Or individually:
cd src/agentic-api  && uv run fastapi dev main.py
cd src/orchestrator && uv run fastapi dev main.py
cd src/agentic-ui   && npm run dev

# Deploy to Azure
azd up
```

## spec-driven development (spec2cloud)

This shell carries the spec2cloud framework in `.github/` and SDD state in `.spec2cloud/`.
Start (or resume) the workflow — pick **greenfield** (new product) or **brownfield** (reverse-
engineer existing code):

```bash
apm run prd       # or: copilot --allow-tool -p .github/prompts/prd.prompt.md
apm run frd
apm run plan
apm run implement # or: apm run delegate
apm run deploy
```

`.spec2cloud/state.json` is the resumable source of truth; `.spec2cloud/audit.log` is the
append-only trail. See `.github/skills/state-management` and `.github/skills/resume`.

## Environment Variables

**BFF** (`src/agentic-api/.env`): `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT_NAME`, `ORCHESTRATOR_URL`
**Orchestrator** (`src/orchestrator/.env`): `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT_NAME`
**Frontend** (`src/agentic-ui/.env.local`): `AGENT_API_URL`

## Key Files

| Path | Purpose |
|------|---------|
| `apphost.cs` | .NET Aspire orchestration (api + orchestrator + ui) |
| `src/agentic-api/app.py` | FastAPI BFF application factory (example routes) |
| `src/orchestrator/graph.py` | LangGraph example turn — replace with your domain agent |
| `src/agentic-ui/app/page.tsx` | React landing page |
| `infra/main.bicep` | Subscription-scoped IaC entry point |
| `infra/resources.bicep` | Container Apps env, ACR, managed identity, container apps |

## Architecture

```
Browser → Next.js (agentic-ui) → FastAPI BFF (agentic-api) → LangGraph (orchestrator) → AI Foundry model
```

- **Three Container Apps**, all using **managed identity** — no secrets in code.
- **BFF pattern**: the browser only talks to the BFF; the orchestrator is internal.
- **Streaming**: SSE (`text/event-stream`) is the documented pattern for agent output.

## Code Style

**Python**: PEP 8, 100-char lines, 4-space indent, type hints required, async where I/O-bound
**TypeScript**: 2-space indent, strict mode, explicit types
**Bicep**: 2-space indent, `@description()` on all params, Azure Verified Modules

## Common Commands

```bash
# Dependencies
cd src/agentic-api  && uv pip install -e .
cd src/orchestrator && uv pip install -e .
cd src/agentic-ui   && npm install

# Tests
cd src/agentic-api  && uv run pytest
cd src/orchestrator && uv run pytest

# Lint / build (frontend)
cd src/agentic-ui && npm run lint && npm run build

# Deploy
azd up          # Full provision + deploy
azd deploy      # Code only
azd provision   # Infrastructure only
```

## Adding Resources

**Python dependency**: add to `pyproject.toml`, run `uv pip install -e .`
**Node dependency**: `npm install <package>`
**Azure resource**: add to `infra/resources.bicep`, run `azd provision`
**API endpoint**: add routes to `src/agentic-api/app.py`
**Agent step**: add a node to `src/orchestrator/graph.py`

## Production Checklist (wire these as you build)

1. Authentication — Entra ID + MSAL + On-Behalf-Of (pattern documented; not wired in the shell)
2. Authorization — enforce RBAC in the BFF, never only in the frontend
3. Input validation — Pydantic models on every request body
4. Rate limiting — APIM AI Gateway + a per-instance guard
5. Observability — OpenTelemetry → Application Insights
6. Tests — pytest (backend), Vitest + Playwright (frontend)
