# willform-plugins

Claude Code plugin for [Willform Agent](https://agent.willform.ai) — deploy, monitor, and manage Kubernetes workloads from your terminal.

## Install

```
/install-plugin willform-ai/willform-plugins
```

Or clone and use locally:

```bash
git clone https://github.com/willform-ai/willform-plugins.git
claude --plugin-dir willform-plugins
```

## Setup

```
/wf-setup
```

You'll need a Willform Agent API key (`wf_sk_*`). Get one from the [dashboard](https://agent.willform.ai/dashboard).

Configuration is stored in `~/.claude/willform-plugins.local.md`:

```
api_key: wf_sk_your_key_here
base_url: https://agent.willform.ai
language: en
```

## Commands

### Getting Started

| Command | Description |
|---------|-------------|
| `/wf-help` | Show all commands and quick start guide |
| `/wf-setup` | Configure API key, base URL, and language |

### Deploy

| Command | Description |
|---------|-------------|
| `/wf-deploy` | Deploy any container with interactive configuration |
| `/wf-template` | Browse and deploy from pre-built templates |
| `/wf-build-push` | Build Docker image and push to GHCR or Docker Hub |

### Monitor

| Command | Description |
|---------|-------------|
| `/wf-status` | Check deployment status (all or specific) |
| `/wf-logs <name>` | View container logs |
| `/wf-monitor` | Deployment health check and issue diagnosis |
| `/wf-diagnose <name>` | Deep diagnosis with logs, events, and fixes |

### Manage

| Command | Description |
|---------|-------------|
| `/wf-namespace` | List, create, update, or delete namespaces |
| `/wf-scale <name>` | Scale, stop, restart, or delete a deployment |
| `/wf-env <name>` | View or update environment variables |
| `/wf-domain` | Expose deployments and manage custom domains |

### Billing

| Command | Description |
|---------|-------------|
| `/wf-cost` | Credit balance and burn rate estimate |
| `/wf-credits` | Deposit options and transaction verification |

### Agent

| Command | Description |
|---------|-------------|
| `/wf-agent` | Interact with Willy AI agent |

## Quick Start

```
/wf-setup                  # Set your API key
/wf-deploy                 # Deploy a container
/wf-status                 # Verify it's running
/wf-monitor                # Health check and diagnose issues
/wf-cost                   # Check your spending
```

## Architecture

```
skills/                     # Slash commands (SKILL.md per command)
  wf-help/
  wf-setup/
  wf-deploy/
  ...
agents/
  willform-ops.md           # Multi-step ops agent
hooks/
  hooks.json                # SessionStart hook
scripts/
  wf-api.sh                 # Shared API helper
```

Each command is a standalone `SKILL.md` file with YAML frontmatter. The shared `wf-api.sh` script handles authentication, HTTP methods, and MCP tool calls.

### API Access

- **REST** — standard CRUD via `wf_get`, `wf_post`, `wf_put`, `wf_delete`
- **MCP** — tool calls via `wf_mcp` for operations with no REST equivalent (preflight, agent ops, env update)

## Language

All commands support English and Korean. Set your preference during `/wf-setup` or edit `~/.claude/willform-plugins.local.md`:

```
language: en   # or ko
```

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for how to add new commands.

## License

[MIT](./LICENSE)
