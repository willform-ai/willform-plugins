# Contributing to willform-plugins

Add new skills (slash commands) to the Willform Agent CLI plugin.

## Skill Format

Each skill lives in `skills/{name}/SKILL.md` with YAML frontmatter:

```yaml
---
name: wf-{command}
description: {Imperative verb} {what it does} on Willform Agent
allowed-tools: Bash, Read[, Write, AskUserQuestion]
user-invocable: true
---
```

### Required Sections

```markdown
# /wf-{command} -- {Human-Readable Title}

## Goal
One paragraph describing what this skill does.

## Language
After loading config, check `WF_LANGUAGE` (set by `wf_load_config`).
Use English if `en` or empty, Korean if `ko`.
If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

### Step 1: Load API config
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config

### Step 2-N: {Workflow steps}
{Use wf_get, wf_post, wf_put, wf_delete for API calls}

### Step N: Report result
{Show output in user's language}

## Error Handling
{Common failure scenarios and fixes}
```

### Naming Rules

- Skill directory and `name:` field must match: `wf-{command}`
- h1 format: `# /wf-{command} -- {Title}`
- Lowercase, hyphen-separated

### allowed-tools Selection

| Tool | When to include |
|------|----------------|
| `Bash` | Always — needed for API calls via wf-api.sh |
| `Read` | Always — needed for reading config and skill files |
| `Write` | Only if the skill creates/modifies files (e.g., Dockerfile) |
| `AskUserQuestion` | Only if the skill needs interactive user input |

## API Helper

All skills use the shared helper at `scripts/wf-api.sh`:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config

# HTTP methods
response=$(wf_get "/api/deploy")
response=$(wf_post "/api/deploy" "$JSON_BODY")
response=$(wf_put "/api/namespaces/${ID}" "$JSON_BODY")
response=$(wf_delete "/api/deploy/${ID}")

# JSON parsing
value=$(wf_json_field "$response" "data.id")
success=$(wf_json_success "$response")
```

Responses follow `{ success: boolean, data?: T, error?: string }` format.

### MCP Tools (no REST equivalent)

Some operations are only available via MCP JSON-RPC. Use the `wf_mcp` helper:

```bash
# wf_mcp <tool_name> '<json_arguments>'
# Returns the text content from the MCP response (parsed from SSE)

# Examples:
result=$(wf_mcp "deploy_preflight" "{\"namespaceId\":\"${NS_ID}\",\"image\":\"nginx:latest\",\"chartType\":\"web\",\"name\":\"my-app\"}")
result=$(wf_mcp "agent_status" "{\"namespaceId\":\"${NS_ID}\"}")
result=$(wf_mcp "deploy_update_env" "{\"deploymentId\":\"${ID}\",\"env\":{\"KEY\":\"val\"},\"merge\":true}")
result=$(wf_mcp "chart_list" "{}")
```

MCP-only tools: `deploy_preflight`, `deploy_update_env`, `agent_status`, `agent_chat`, `agent_recover`, `agent_invoke`, `chart_list`.

## Language Support

Every skill must support English and Korean output. Check `WF_LANGUAGE`:

```bash
if [[ "$WF_LANGUAGE" == "ko" ]]; then
  # Korean output
else
  # English output (default)
fi
```

## Checklist

Before submitting a PR:

- [ ] `skills/{name}/SKILL.md` has correct frontmatter (`name`, `description`, `allowed-tools`, `user-invocable: true`)
- [ ] h1 follows `# /wf-{command} -- {Title}` format
- [ ] Step 1 loads API config via `wf_load_config`
- [ ] Language section handles both en and ko
- [ ] Error handling covers 401 (bad key), 402 (low credits), 404 (not found)
- [ ] `/wf-help` SKILL.md updated with new command (both English and Korean sections)
- [ ] `CLAUDE.md` command table updated
- [ ] `README.md` command table updated
- [ ] `claude plugin validate .` passes
