---
name: wf-deploy-openclaw
description: Deploy an OpenClaw AI agent (with optional soul preset) to Willform Agent
allowed-tools: Bash, Read, Write, AskUserQuestion
user-invocable: true
---

# /wf-deploy-openclaw — Deploy OpenClaw Agent

## Goal

Deploy an OpenClaw AI agent runtime to Willform Agent with Telegram integration. Guides the user through the full setup: Telegram bot creation, LLM provider selection, API key configuration, soul selection, and deployment.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. See `skills/willform-deploy/references/language-guidelines.md` for output conventions. If not set, ask the user to choose (English/한국어) and save to config.

## Steps

### 1. Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### 2. Telegram Bot setup guide

Show the user how to create a Telegram bot:

```
To connect your AI agent to Telegram, you need a bot token from @BotFather.

1. Open Telegram and search for @BotFather
2. Send /newbot
3. Choose a display name for your bot (e.g., "My AI Agent")
4. Choose a username ending in "bot" (e.g., "my_ai_agent_bot")
5. Copy the token BotFather gives you

Token format: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz
```

Use AskUserQuestion to collect the token. Validate that it matches the pattern `[0-9]+:[A-Za-z0-9_-]+`.

Also ask for the bot username (without @) — this is needed to generate the `https://t.me/{bot_username}` link in the final report.

If the user wants to skip Telegram integration, allow it — `TELEGRAM_BOT_TOKEN` is optional.

### 3. Choose LLM provider

Use AskUserQuestion to let the user pick their LLM provider:

- **OpenRouter** (Recommended) — Access all models (Claude, GPT, Gemini, etc.) with one key. https://openrouter.ai/keys
- **OpenAI** — GPT-4o, GPT-4o-mini. https://platform.openai.com/api-keys
- **Anthropic** — Claude Sonnet, Claude Haiku. https://console.anthropic.com/settings/keys
- **Google Gemini** — Gemini 2.0 Flash, Gemini 2.0 Pro. https://aistudio.google.com/apikey

### 4. Collect API key

Show the key signup URL for the selected provider:

| Provider | Key URL | Key prefix |
|----------|---------|------------|
| OpenRouter | https://openrouter.ai/keys | `sk-or-` |
| OpenAI | https://platform.openai.com/api-keys | `sk-` |
| Anthropic | https://console.anthropic.com/settings/keys | `sk-ant-` |
| Google Gemini | https://aistudio.google.com/apikey | `AIza` |

Use AskUserQuestion to collect the key. Validate the prefix matches the selected provider.

### 5. Choose soul (personality preset)

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
- Use the model suggestion matching the selected provider (e.g., if Anthropic → `claude-sonnet-4-20250514`, if OpenAI → `gpt-4o`)
- Let the user override any pre-filled value if they want

If user selects "custom":
- Proceed with manual input (no pre-filled values)

### 6. Gather user input

Use AskUserQuestion for each. Skip items already filled by the soul preset (but allow override):

1. **Agent name** (required): Used as deployment name and `AGENT_NAME` env var. Must be lowercase alphanumeric with hyphens, no spaces. If soul selected, suggest a default (e.g., `real-estate-advisor`).

2. **Agent model** (optional): Default from soul preset for the selected provider. Show provider-specific options:
   - OpenRouter: `anthropic/claude-sonnet-4-20250514`, `openai/gpt-4o`, `google/gemini-2.0-flash`
   - OpenAI: `gpt-4o`, `gpt-4o-mini`
   - Anthropic: `claude-sonnet-4-20250514`, `claude-haiku-4.5`
   - Google: `gemini-2.0-flash`, `gemini-2.0-pro`

3. **Agent description** (optional): Pre-filled from soul if selected.

4. **System prompt** (optional): Pre-filled from soul. For custom soul, ask the user to provide one. The user can also modify a preset's system prompt.

5. **Namespace**: Ask whether to create a new namespace or use an existing one.
   - If existing: list namespaces via `wf_get "/api/namespaces"` and let user pick
   - If new: ask for namespace name (default: same as agent name)

### 7. Create namespace (if needed)

```bash
RESULT=$(wf_post "/api/namespaces" "{\"name\":\"${NAMESPACE_NAME}\",\"allocatedCores\":2,\"allocatedMemoryGb\":4}")
NAMESPACE_ID=$(wf_json_field "$RESULT" "data.id")
SHORT_ID=$(wf_json_field "$RESULT" "data.shortId")
```

OpenClaw needs 2 cores / 4GB memory. `allocatedCores` and `allocatedMemoryGb` are required fields.

If using an existing namespace, extract `NAMESPACE_ID` and `SHORT_ID` from the selected namespace. Verify the namespace has sufficient quota (at least 2 cores, 4GB memory).

### 8. Deploy OpenClaw

Build the env JSON with provider-specific key mapping:

```bash
# Determine the LLM key env var name based on provider
case "$PROVIDER" in
  openrouter) LLM_KEY_VAR="OPENROUTER_API_KEY" ;;
  openai)     LLM_KEY_VAR="OPENAI_API_KEY" ;;
  anthropic)  LLM_KEY_VAR="ANTHROPIC_API_KEY" ;;
  google)     LLM_KEY_VAR="GOOGLE_API_KEY" ;;
esac

# Build env JSON
ENV_JSON=$(jq -n \
  --arg llm_key_var "$LLM_KEY_VAR" \
  --arg llm_key "$LLM_API_KEY" \
  --arg model "$MODEL" \
  --arg name "$AGENT_NAME" \
  --arg desc "$AGENT_DESCRIPTION" \
  --arg prompt "$AGENT_SYSTEM_PROMPT" \
  --arg tg_token "$TELEGRAM_BOT_TOKEN" \
  '{
    ($llm_key_var): $llm_key,
    AGENT_MODEL: $model,
    AGENT_NAME: $name
  }
  + (if $tg_token != "" then {TELEGRAM_BOT_TOKEN: $tg_token} else {} end)
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

### 9. Expose default domain

```bash
RESULT=$(wf_post "/api/deploy/${DEPLOYMENT_ID}/expose")
DOMAIN=$(wf_json_field "$RESULT" "data.hostname")
```

### 10. Poll for readiness

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

### 11. Report result

On success, display:

```
OpenClaw agent deployed successfully.

  Name:      {agent_name}
  Soul:      {soul_name} (or "custom")
  Provider:  {provider}
  Model:     {model}
  URL:       https://{domain}
  Telegram:  https://t.me/{bot_username}  (if Telegram was configured)
  Status:    running

Use /wf-status to check deployment health.
Use /wf-logs to view agent logs.
```

If Telegram was configured, add: "Open the Telegram link above to start chatting with your agent."

On failure or timeout, display the error and suggest checking logs with `wf_get "/api/deploy/${DEPLOYMENT_ID}/logs"`.
