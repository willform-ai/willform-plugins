# willform-plugins

Claude Code plugin for [Willform Agent](https://agent.willform.ai) — deploy, monitor, and manage Kubernetes workloads from your terminal.

## Install

```bash
claude install-plugin willform-ai/willform-plugins
```

Or clone and use directly:

```bash
git clone https://github.com/willform-ai/willform-plugins.git
claude --plugin-dir willform-plugins
```

## Setup

```
/wf-setup
```

You'll need a Willform Agent API key (`wf_sk_*`). Get one from the [dashboard](https://agent.willform.ai/dashboard).

## Commands

| Command | Description |
|---------|-------------|
| `/wf-help` | Show all commands and quick start guide |
| `/wf-setup` | Configure API key, base URL, and language |
| `/wf-deploy-openclaw` | Deploy an OpenClaw AI agent with soul presets |
| `/wf-build-push` | Build Docker image and push to GHCR |
| `/wf-status` | Check deployment status |
| `/wf-status <name>` | Detailed status for a specific deployment |
| `/wf-logs <name>` | View container logs |
| `/wf-cost` | Credit balance and burn rate estimate |

## Quick Start

```
/wf-setup                  # Set your API key
/wf-deploy-openclaw        # Deploy an AI agent
/wf-status                 # Verify it's running
/wf-cost                   # Check your spending
```

## OpenClaw Soul Presets

`/wf-deploy-openclaw` includes personality presets that pre-configure the agent's expertise:

- **real-estate-expert** — Property valuation, market analysis, ROI projections
- **stock-investment-expert** — Fundamental/technical analysis, portfolio management
- **legal-assistant** — Contract analysis, compliance, corporate law
- **coding-mentor** — Guided learning, code review, project-based teaching
- **data-analyst** — Statistical analysis, SQL, visualization
- **writing-coach** — Editing, content strategy, style improvement
- **custom** — Start from scratch with your own system prompt

## Skills (Reference)

These skills provide context for Claude when working with Willform:

| Skill | Description |
|-------|-------------|
| `willform-deploy` | Deployment workflow and REST API reference |
| `dockerfile-build` | Dockerfile templates and GHCR authentication |
| `deploy-monitoring` | Status interpretation and diagnostic guide |
| `cost-tracking` | Pricing tables and cost calculation |

## Language

All commands support English and Korean. Set your preference during `/wf-setup` or change it anytime by editing `~/.claude/willform-plugins.local.md`:

```
language: en   # or ko
```

## Pricing

| Resource | Rate |
|----------|------|
| Compute | $0.04/core/hr |
| Memory | $0.005/GB/hr |
| Storage | $0.0001/GB/hr |

Per-second billing. Namespace suspended at balance <= $0.01.

## License

MIT
