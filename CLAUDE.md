# Willform Plugins

Claude Code plugin for Willform Agent — deploy, monitor, and manage K8s workloads from the CLI.

## Repository

- GitHub: `willform-ai/willform-plugins` (public)
- Marketplace: `.claude-plugin/marketplace.json`
- Plugin manifest: `.claude-plugin/plugin.json`

## Structure

```
skills/
  wf-*/SKILL.md        — Slash commands (user-invocable: true)
  willform-deploy/     — Deploy workflow reference skill
  dockerfile-build/    — Dockerfile + GHCR reference skill
  deploy-monitoring/   — Status/logs reference skill
  cost-tracking/       — Pricing reference skill
agents/
  willform-ops.md      — Multi-step ops agent
hooks/
  hooks.json           — SessionStart hook
scripts/
  wf-api.sh            — Shared API helper (wf_load_config, wf_get, wf_post, etc.)
```

## Slash Commands

7 commands registered via `skills/{name}/SKILL.md` with `user-invocable: true`:

| Command | Description |
|---------|-------------|
| `/wf-help` | All commands + quick start |
| `/wf-setup` | API key + language config |
| `/wf-deploy-openclaw` | Deploy OpenClaw agent with Telegram + multi-provider LLM |
| `/wf-build-push` | Dockerfile + GHCR push |
| `/wf-status` | Deployment status |
| `/wf-logs` | Container logs |
| `/wf-cost` | Credit balance + burn rate |

## Conventions

- All commands load config via `source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config`
- User config stored in `~/.claude/willform-plugins.local.md` (gitignored via `*.local.md`)
- Config fields: `api_key`, `base_url`, `language` (en/ko)
- Language check: `WF_LANGUAGE` env var set by `wf_load_config`. All commands support en/ko output
- Language guidelines: `skills/willform-deploy/references/language-guidelines.md`
- API base URL default: `https://agent.willform.ai`
- Auth header: `Authorization: Bearer wf_sk_*`

## Plugin Architecture

- SKILL.md frontmatter requires: `name`, `description`, `allowed-tools`, `user-invocable: true`
- `name:` field = slash command name (e.g., `name: wf-status` → `/wf-status`)
- Marketplace `source` paths must start with `./` (not `.`)
- Validate: `claude plugin validate .`

## Adding a New Command

1. Create `skills/{command-name}/SKILL.md` with frontmatter
2. Add Language section (check `WF_LANGUAGE`, reference language-guidelines.md)
3. Use `source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config` as first step
4. Update `/wf-help` SKILL.md command table
5. Update README.md command table

## Related Project

- Willform Agent (`~/Projects/infra-agent`): The platform this plugin targets
- REST API docs: `skills/willform-deploy/references/api-reference.md`
