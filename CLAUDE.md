# Willform Plugins

Claude Code plugin for Willform Agent — deploy, monitor, and manage K8s workloads from the CLI.

## Repository

- GitHub: `willform-ai/willform-plugins` (public)
- Marketplace: `.claude-plugin/marketplace.json`
- Plugin manifest: `.claude-plugin/plugin.json`

## Structure

```
skills/
  wf-help/             — All commands + quick start
  wf-setup/            — API key + language config
  wf-deploy/           — Deploy any container interactively
  wf-template/         — Browse and deploy from templates
  wf-build-push/       — Dockerfile + GHCR/Docker Hub push
  wf-status/           — Deployment status
  wf-logs/             — Container logs
  wf-monitor/          — Deployment health check + diagnosis
  wf-diagnose/         — Deep diagnosis with logs + events
  wf-namespace/        — Namespace CRUD
  wf-scale/            — Scale, stop, restart, delete deployments
  wf-env/              — Environment variable management
  wf-domain/           — Custom domains + expose/unexpose
  wf-cost/             — Credit balance + burn rate
  wf-credits/          — Deposit options + tx verification
  wf-agent/            — Willy AI agent interaction
  openclaw-willform-deploy/ — OpenClaw skill: deploy to Willform via natural language
agents/
  willform-ops.md      — Multi-step ops agent
hooks/
  hooks.json           — SessionStart hook
scripts/
  wf-api.sh            — Shared API helper (wf_load_config, wf_get, wf_post, etc.)
```

## Slash Commands

16 commands registered via `skills/{name}/SKILL.md` with `user-invocable: true`:

| Command | Description |
|---------|-------------|
| `/wf-help` | All commands + quick start |
| `/wf-setup` | API key + language config |
| `/wf-deploy` | Deploy any container with interactive configuration |
| `/wf-template` | Browse and deploy from templates |
| `/wf-build-push` | Dockerfile + GHCR/Docker Hub push |
| `/wf-status` | Deployment status |
| `/wf-logs` | Container logs |
| `/wf-monitor` | Deployment health check + diagnosis |
| `/wf-diagnose` | Deep diagnosis with logs, events, and fixes |
| `/wf-namespace` | Namespace CRUD (list, create, update, delete) |
| `/wf-scale` | Scale, stop, restart, or delete deployments |
| `/wf-env` | View or update environment variables |
| `/wf-domain` | Custom domains + expose/unexpose |
| `/wf-cost` | Credit balance + burn rate |
| `/wf-credits` | Deposit options + transaction verification |
| `/wf-agent` | Willy AI agent interaction |

## OpenClaw Skill

`skills/openclaw-willform-deploy/SKILL.md` is an OpenClaw-native skill (NOT a Claude Code slash command).
It uses OpenClaw's SKILL.md format with `metadata.openclaw` frontmatter, not `user-invocable: true`.

- Install on OpenClaw: `clawhub install willform-deploy` or paste GitHub URL in chat
- Requires: `WF_API_KEY` env var, `curl`, `jq`
- Uses `wf_mcp()` inline function to call Willform MCP endpoint via curl
- Key flow: `deploy_plan` (natural language -> ordered steps) -> `deploy_create` -> `deploy_expose`

## Conventions

- All commands load config via `source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config` (except `/wf-setup`, which creates the config)
- User config stored in `~/.claude/willform-plugins.local.md` (gitignored via `*.local.md`)
- Config fields: `api_key`, `base_url`, `language` (en/ko)
- Language: Each skill checks `WF_LANGUAGE` from config (en/ko)
- API base URL default: `https://agent.willform.ai`
- Auth header: `Authorization: Bearer wf_sk_*`

## Plugin Architecture

- SKILL.md frontmatter requires: `name`, `description`, `allowed-tools`, `user-invocable: true`
- `name:` field = slash command name (e.g., `name: wf-status` → `/wf-status`)
- Marketplace `source` paths must start with `./` (not `.`)
- Validate: `claude plugin validate .`

## Adding a New Command

1. Create `skills/{command-name}/SKILL.md` with frontmatter
2. Add Language section (check `WF_LANGUAGE` from config, support en/ko output)
3. Use `source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config` as first step
4. Update `/wf-help` SKILL.md command table
5. Update README.md command table

## API Access Patterns

- **REST**: `wf_get`, `wf_post`, `wf_put`, `wf_delete` — for standard CRUD endpoints
- **MCP**: `wf_mcp <tool> '<args>'` — for tools with no REST equivalent (preflight, agent ops, env update, chart list)
- MCP endpoint returns SSE; `wf_mcp` handles parsing automatically

## Related Project

- Willform Agent (`~/Projects/willform-agent`): The platform this plugin targets (has MCP server at /api/mcp)
- REST API: All skills use `wf-api.sh` helper to call `https://agent.willform.ai` endpoints
