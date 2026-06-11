## Build your app with spec2cloud (SDD)

This shell is a [spec2cloud](https://github.com/EmeaAppGbb/spec2cloud) project developed and maintained by Microsoft EMEA GBB (Global Black Belt) team members.
Pick a path and let the agents drive:

- **Greenfield** - start from a product idea → PRD → FRD → tests → contracts → implement → deploy.
- **Brownfield** - reverse-engineer existing code → extract → spec-enable → testability gate →
  green baseline / behavioral docs → deliver. (This very repo was produced via the brownfield idea;
  see [`docs/analysis/`](docs/analysis/).)

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#E6F2FA','primaryTextColor':'#323130','primaryBorderColor':'#0078D4','secondaryColor':'#E6F2FA','secondaryTextColor':'#323130','secondaryBorderColor':'#0078D4','tertiaryColor':'#E6F2FA','tertiaryTextColor':'#323130','tertiaryBorderColor':'#0078D4','clusterBkg':'#E6F2FA','clusterBorder':'#0078D4','titleColor':'#323130','textColor':'#323130','edgeLabelBackground':'#ffffff','lineColor':'#005A9E','fontFamily':'Segoe UI'}}}%%
flowchart TD
    Start["Adopt the shell<br/><i>fill placeholders</i>"]
    Mode{"Greenfield<br/>or brownfield?"}
    PRD["apm run prd<br/><i>idea → PRD</i>"]
    REV["apm run rev-eng<br/><i>extract from code</i>"]
    FRD["apm run frd<br/><i>functional spec + tests</i>"]
    PLAN["apm run plan<br/><i>increment plan</i>"]
    IMPL["apm run implement<br/><i>or delegate</i>"]
    DEPLOY["apm run deploy<br/><i>azd up</i>"]
    Gate{"Human gate"}

    STATE[(".spec2cloud/<br/>state.json")]
    AUDIT[(".spec2cloud/<br/>audit.log")]

    Start --> Mode
    Mode -->|greenfield| PRD
    Mode -->|brownfield| REV
    PRD --> FRD
    REV --> FRD
    FRD --> PLAN
    PLAN --> Gate
    Gate -->|approved| IMPL
    IMPL --> DEPLOY
    Gate -.resume.-> STATE
    PRD & REV & FRD & PLAN & IMPL & DEPLOY -.write progress.-> STATE
    PRD & REV & FRD & PLAN & IMPL & DEPLOY -.append.-> AUDIT
    STATE -.read on resume.-> Mode

    classDef userNode fill:#005A9E,stroke:#004578,color:#fff
    classDef appNode fill:#0078D4,stroke:#004578,color:#fff
    classDef paasNode fill:#E6F2FA,stroke:#0078D4,color:#323130
    classDef dataNode fill:#107C10,stroke:#004578,color:#fff

    class Start userNode
    class PRD,REV,FRD,PLAN,IMPL,DEPLOY appNode
    class STATE,AUDIT dataNode
```

```bash
apm install        # install the APM standards referenced in apm.yml
apm run prd        # or: copilot --allow-tool -p .github/prompts/prd.prompt.md
apm run frd
apm run plan
apm run implement  # or: apm run delegate
apm run deploy
```

State is resumable: `.spec2cloud/state.json` records `currentPhase`/progress and
`.spec2cloud/audit.log` records every significant action. A missing `state.json` starts at
Phase 0; the included one is a clean Phase 0 ready to begin. See `.github/skills/state-management`
and `.github/skills/resume`.

## Make it yours

1. Rename the project: `azure.yaml` `name:`, `SPEC2CLOUD.md` metadata, this README, `LICENSE.md`.
2. Fill placeholders (see [`docs/analysis/08-placeholders.md`](docs/analysis/08-placeholders.md)).
3. Replace the example routes / graph node / landing page with your domain.
4. Wire the production checklist in [`AGENTS.md`](AGENTS.md) (auth, RBAC, validation, telemetry, tests).