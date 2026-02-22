---
name: wf-deploy-openclaw
description: Deploy an OpenClaw AI agent (with optional soul preset) to Willform Agent
allowed-tools: Bash, Read, Write, AskUserQuestion
user-invocable: true
---

# /wf-deploy-openclaw — Deploy OpenClaw Agent

## Goal

Deploy an OpenClaw AI agent runtime to Willform Agent. Optionally select a "soul" — a pre-configured personality template that sets the agent's expertise and system prompt.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. See `skills/willform-deploy/references/language-guidelines.md` for output conventions. If not set, ask the user to choose (English/한국어) and save to config.

## Steps

### 1. Load API config

```bash
source scripts/wf-api.sh && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### 2. Choose soul (personality preset)

Read the soul catalog from `skills/willform-deploy/references/openclaw-souls.md`.

Use AskUserQuestion to let the user pick a soul:

- **real-estate-expert** — Real estate investment analyst (market analysis, property valuation, ROI projections)
- **stock-investment-expert** — Stock analyst (fundamental/technical analysis, portfolio management)
- **legal-assistant** — Legal research assistant (contract analysis, compliance, corporate law)
- **coding-mentor** — Programming tutor (guided learning, code review, project-based teaching)
- **data-analyst** — Data analyst (statistical analysis, SQL, visualization, business insights)
- **writing-coach** — Writing assistant (editing, content strategy, style improvement)
- **custom** — Start from scratch with your own system prompt

If user selects a preset soul:
- Pre-fill `AGENT_NAME`, `AGENT_DESCRIPTION`, `AGENT_SYSTEM_PROMPT`, and suggested model from the catalog
- Let the user override any pre-filled value if they want

If user selects "custom":
- Proceed with manual input (no pre-filled values)

### 3. Gather user input

Use AskUserQuestion for each. Skip items already filled by the soul preset (but allow override):

1. **Agent name** (required): Used as deployment name and `AGENT_NAME` env var. Must be lowercase alphanumeric with hyphens, no spaces. If soul selected, suggest a default (e.g., `real-estate-advisor`).

2. **OPENROUTER_API_KEY** (required): Their OpenRouter API key for LLM access. Starts with `sk-or-`.

3. **Agent model** (optional): Default from soul preset, or `claude-sonnet-4-20250514` if custom. Some souls suggest `claude-haiku-4.5` for faster interaction.

4. **Agent description** (optional): Pre-filled from soul if selected.

5. **System prompt** (optional): Pre-filled from soul. For custom soul, ask the user to provide one. The user can also modify a preset's system prompt.

6. **Namespace**: Ask whether to create a new namespace or use an existing one.
   - If existing: list namespaces via `wf_get "/api/namespaces"` and let user pick
   - If new: ask for namespace name (default: same as agent name)

### 4. Create namespace (if needed)

```bash
RESULT=$(wf_post "/api/namespaces" "{\"name\":\"${NAMESPACE_NAME}\",\"allocatedCores\":2,\"allocatedMemoryGb\":4}")
NAMESPACE_ID=$(wf_json_field "$RESULT" "data.id")
SHORT_ID=$(wf_json_field "$RESULT" "data.shortId")
```

OpenClaw needs 2 cores / 4GB memory. `allocatedCores` and `allocatedMemoryGb` are required fields.

If using an existing namespace, extract `NAMESPACE_ID` and `SHORT_ID` from the selected namespace. Verify the namespace has sufficient quota (at least 2 cores, 4GB memory).

### 5. Deploy OpenClaw

Build the env JSON. Include `AGENT_SYSTEM_PROMPT` from the soul preset (or user input). Only include optional fields if values are provided.

```bash
ENV_JSON=$(jq -n \
  --arg api_key "$OPENROUTER_API_KEY" \
  --arg model "$MODEL" \
  --arg name "$AGENT_NAME" \
  --arg desc "$AGENT_DESCRIPTION" \
  --arg prompt "$AGENT_SYSTEM_PROMPT" \
  '{
    OPENROUTER_API_KEY: $api_key,
    AGENT_MODEL: $model,
    AGENT_NAME: $name
  }
  + (if $desc != "" then {AGENT_DESCRIPTION: $desc} else {} end)
  + (if $prompt != "" then {AGENT_SYSTEM_PROMPT: $prompt} else {} end)')

RESULT=$(wf_post "/api/deploy" "{
  \"namespaceId\": \"${NAMESPACE_ID}\",
  \"name\": \"${AGENT_NAME}\",
  \"image\": \"alpine/openclaw:2026.2.13\",
  \"chartType\": \"web\",
  \"port\": 18789,
  \"env\": ${ENV_JSON}
}")

DEPLOYMENT_ID=$(wf_json_field "$RESULT" "data.deploymentId")
```

If the deploy call fails, show the error and stop.

### 6. Expose default domain

```bash
RESULT=$(wf_post "/api/deploy/${DEPLOYMENT_ID}/expose")
DOMAIN=$(wf_json_field "$RESULT" "data.hostname")
```

### 7. Poll for readiness

Poll `GET /api/deploy/{id}` every 5 seconds, max 120 seconds (24 attempts):

```bash
for i in $(seq 1 24); do
  RESULT=$(wf_get "/api/deploy/${DEPLOYMENT_ID}")
  STATUS=$(wf_json_field "$RESULT" "data.status")
  if [[ "$STATUS" == "running" ]]; then
    break
  elif [[ "$STATUS" == "failed" ]]; then
    echo "Deployment failed." >&2
    wf_get "/api/deploy/${DEPLOYMENT_ID}/logs"
    break
  fi
  sleep 5
done
```

### 8. Report result

On success, display:

```
OpenClaw agent deployed successfully.

  Name:   {agent_name}
  Soul:   {soul_name} (or "custom")
  Model:  {model}
  URL:    https://{domain}
  Status: running

Use /wf-status to check deployment health.
Use /wf-logs to view agent logs.
```

On failure or timeout, display the error and suggest checking logs with `wf_get "/api/deploy/${DEPLOYMENT_ID}/logs"`.
