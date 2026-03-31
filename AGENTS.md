# AGENTS.md — willform-plugins

## For All Agents

### Risk Awareness
- Read `.github/risk-tiers.json` before making changes
- `skills/**` and `scripts/**` are HIGH risk — require 1 human + AI review
- This is a **public repo** — never commit secrets, API keys, or credentials in any file
- `*.md` and `LICENSE` are LOW risk — auto-merge eligible

### Repository Structure
```
skills/{name}/SKILL.md   — Slash commands (one directory per command)
scripts/wf-api.sh        — Shared API helper (all skills depend on this)
agents/willform-ops.md   — Multi-step ops agent definition
hooks/hooks.json         — SessionStart hook
.claude-plugin/          — Plugin manifest (marketplace + plugin config)
```

### Forbidden Patterns
- Hardcoded API keys, tokens, or credentials (public repo)
- `user-invocable: true` on non-slash-command skills (e.g., OpenClaw skills use `metadata.openclaw` instead)
- Modifying `wf-api.sh` function signatures without updating all consuming skills
- Removing or renaming the `wf_load_config` call pattern
- `echo` for piping secrets (use `printf '%s'` to avoid trailing newline issues)

## For Code Review Agents

### Review Protocol
1. Check risk tier of changed files against `.github/risk-tiers.json`
2. Scan for leaked secrets, API keys, hardcoded URLs with credentials
3. Verify SKILL.md frontmatter format (see SKILL.md Requirements below)
4. Verify language support (both en and ko)
5. Check that `/wf-help`, `CLAUDE.md`, and `README.md` command tables are updated for new commands

### Severity Levels
- CRITICAL: Secret in code, broken `wf-api.sh` function signature, missing auth header
- IMPORTANT: Missing language support, missing error handling, frontmatter format violation
- MINOR: Style inconsistency, documentation wording

## For Implementation Agents

### Before Starting
1. Read `CLAUDE.md` for project conventions
2. Read `CONTRIBUTING.md` for the skill development checklist
3. Read `scripts/wf-api.sh` to understand available API helpers
4. Read 1-2 existing skills in `skills/` to see the pattern in practice

### SKILL.md Requirements

Every slash command skill must follow this format:

**Frontmatter (required fields):**
```yaml
---
name: wf-{command}
description: {Imperative verb} {what it does} on Willform Agent
allowed-tools: Bash, Read[, Write, AskUserQuestion]
user-invocable: true
---
```

- `name:` must match the directory name under `skills/`
- `description:` starts with an imperative verb (Check, Deploy, View, Manage, etc.)
- `allowed-tools:` always includes `Bash` and `Read`; add `Write` only if the skill creates/modifies files; add `AskUserQuestion` only for interactive input
- `user-invocable: true` is required for slash commands

**Required sections:**
```markdown
# /wf-{command} -- {Human-Readable Title}

## Goal
{One paragraph}

## Language
{Standard language detection block — check WF_LANGUAGE}

## Instructions
### Step 1: Load API config
### Step 2-N: {Workflow steps}
### Step N: Report result

## Error Handling
{401, 402, 404 scenarios at minimum}
```

**Heading format:** `# /wf-{command} -- {Title}` (h1, slash prefix, double dash separator)

**OpenClaw skills** use a different format — `metadata.openclaw` frontmatter instead of `user-invocable: true`, and an inline `wf_mcp()` function instead of sourcing `wf-api.sh`. See `skills/openclaw-willform-deploy/SKILL.md` for the pattern.

### wf-api.sh Usage

Every skill (except `/wf-setup`) must start with:
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

This sets `WF_API_KEY`, `WF_BASE_URL`, and `WF_LANGUAGE` from `~/.claude/willform-plugins.local.md`.

**REST helpers** — for standard CRUD endpoints:
```bash
response=$(wf_get "/api/deploy")
response=$(wf_post "/api/deploy" "$JSON_BODY")
response=$(wf_put "/api/namespaces/${ID}" "$JSON_BODY")
response=$(wf_delete "/api/deploy/${ID}")
```

**MCP helper** — for tools with no REST equivalent:
```bash
result=$(wf_mcp "deploy_preflight" '{"namespaceId":"...","image":"nginx:latest","chartType":"web","name":"app"}')
result=$(wf_mcp "deploy_update_env" '{"deploymentId":"...","env":{"KEY":"val"},"merge":true}')
result=$(wf_mcp "chart_list" '{}')
```

MCP-only tools: `deploy_preflight`, `deploy_update_env`, `agent_status`, `agent_chat`, `agent_recover`, `agent_invoke`, `chart_list`.

**JSON parsing helpers:**
```bash
value=$(wf_json_field "$response" "data.id")
success=$(wf_json_success "$response")
```

API responses follow `{ success: boolean, data?: T, error?: string }` format.

### Language Support

Every skill must support English (`en`) and Korean (`ko`) output. After `wf_load_config`, check `WF_LANGUAGE`:
- `en` or empty → English (default)
- `ko` → Korean

If `WF_LANGUAGE` is unset, ask the user to choose and save to config.

### Error Handling

Every skill must handle at minimum:
- **401** — invalid API key → suggest `/wf-setup`
- **402** — insufficient credits → suggest `/wf-credits`
- **404** — resource not found → show available resources

### New Command Checklist

When adding a new slash command, update these files (per `CONTRIBUTING.md`):
1. `skills/{name}/SKILL.md` — the skill itself
2. `skills/wf-help/SKILL.md` — add to the command table (both English and Korean sections)
3. `CLAUDE.md` — update command table and structure listing
4. `README.md` — update command table

Validate with: `claude plugin validate .`

### Commit Conventions
- `feat:` — new skill or significant skill enhancement
- `fix:` — bug fix in skill logic or wf-api.sh
- `docs:` — documentation-only changes
- `chore:` — config, CI, non-functional changes
- One logical change per commit
