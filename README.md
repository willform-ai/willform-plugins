# willform-plugins

Claude Code plugin for [Willform Agent](https://agent.willform.ai) — deploy, monitor, and manage Kubernetes workloads from your terminal.

## Install

Add the marketplace and install the plugin:

```
/plugin marketplace add willform-ai/willform-plugins
/plugin install willform@willform-plugins
```

Or use directly from a local clone:

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

**Getting Started**

| Command | Description |
|---------|-------------|
| `/wf-help` | Show all commands and quick start guide |
| `/wf-setup` | Configure API key, base URL, and language |

**Deploy**

| Command | Description |
|---------|-------------|
| `/wf-deploy` | Deploy any container with interactive configuration |
| `/wf-template` | Browse and deploy from pre-built templates |
| `/wf-build-push` | Build Docker image and push to GHCR or Docker Hub |

**Monitor**

| Command | Description |
|---------|-------------|
| `/wf-status` | Check deployment status (all or specific) |
| `/wf-logs <name>` | View container logs |
| `/wf-monitor` | Deployment health check and issue diagnosis |
| `/wf-diagnose <name>` | Deep diagnosis with logs, events, and fixes |

**Manage**

| Command | Description |
|---------|-------------|
| `/wf-namespace` | List, create, update, or delete namespaces |
| `/wf-scale <name>` | Scale, stop, restart, or delete a deployment |
| `/wf-env <name>` | View or update environment variables |
| `/wf-domain` | Expose deployments and manage custom domains |

**Billing**

| Command | Description |
|---------|-------------|
| `/wf-cost` | Credit balance and burn rate estimate |
| `/wf-credits` | Deposit options and transaction verification |

**Agent**

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

## Language

All commands support English and Korean. Set your preference during `/wf-setup` or change it anytime by editing `~/.claude/willform-plugins.local.md`:

```
language: en   # or ko
```

## License

MIT
