# OpenClaw Deployment Specification

OpenClaw is an open-source AI agent runtime. This document describes the deployment configuration for running OpenClaw on Willform Agent.

## Image

```
alpine/openclaw:2026.2.13
```

## Network

- Default port: 18789 (AGENT_GATEWAY_PORT)
- Health check: GET /health on port 18789
- Chart type: web

## Required Environment Variables

One LLM API key is required. Use exactly one of the following:

| Variable            | Provider    | Example                       |
|---------------------|-------------|-------------------------------|
| `OPENROUTER_API_KEY`| OpenRouter  | `sk-or-v1-...`                |
| `OPENAI_API_KEY`    | OpenAI      | `sk-...`                      |
| `ANTHROPIC_API_KEY` | Anthropic   | `sk-ant-...`                  |
| `GOOGLE_API_KEY`    | Google Gemini | `AIza...`                   |

Plus these required fields:

| Variable            | Description          | Example                       |
|---------------------|----------------------|-------------------------------|
| `AGENT_MODEL`       | Model name           | `claude-sonnet-4-20250514`    |
| `AGENT_NAME`        | Display name         | `my-agent`                    |

## Optional Environment Variables

| Variable              | Description                        | Default |
|-----------------------|------------------------------------|---------|
| `TELEGRAM_BOT_TOKEN`  | Telegram bot token from @BotFather | —       |
| `AGENT_DESCRIPTION`   | Agent description                  | —       |
| `AGENT_SYSTEM_PROMPT`  | Custom system prompt               | —       |

## Resources

- CPU: 2 cores (AGENT_CPU_CORES)
- Memory: 4 GB (AGENT_MEMORY_GB)

## Deployment Steps

### 1. Create namespace

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
RESULT=$(wf_post "/api/namespaces" '{"name":"my-agent-ns","allocatedCores":2,"allocatedMemoryGb":4}')
NAMESPACE_ID=$(wf_json_field "$RESULT" "data.id")
```

OpenClaw requires 2 CPU cores and 4GB memory, so allocate at least that much.

### 2. Deploy OpenClaw

```bash
RESULT=$(wf_post "/api/deploy" "{
  \"namespaceId\": \"${NAMESPACE_ID}\",
  \"name\": \"my-agent\",
  \"image\": \"alpine/openclaw:2026.2.13\",
  \"chartType\": \"web\",
  \"port\": 18789,
  \"env\": {
    \"OPENROUTER_API_KEY\": \"sk-or-v1-...\",
    \"AGENT_MODEL\": \"claude-sonnet-4-20250514\",
    \"AGENT_NAME\": \"my-agent\"
  }
}")
DEPLOYMENT_ID=$(wf_json_field "$RESULT" "data.deploymentId")
```

### 3. Expose domain

```bash
RESULT=$(wf_post "/api/deploy/${DEPLOYMENT_ID}/expose")
DOMAIN=$(wf_json_field "$RESULT" "data.hostname")
echo "Agent URL: https://${DOMAIN}"
```

### 4. Verify health

Poll until the deployment is running:

```bash
for i in $(seq 1 24); do
  RESULT=$(wf_get "/api/deploy/${DEPLOYMENT_ID}")
  STATUS=$(wf_json_field "$RESULT" "data.status")
  if [[ "$STATUS" == "running" ]]; then
    echo "Agent is healthy"
    break
  elif [[ "$STATUS" == "failed" ]]; then
    echo "Deployment failed"
    break
  fi
  sleep 5
done
```

Then verify the health endpoint:

```bash
curl -s "https://${DOMAIN}/health"
```

## Full Deploy Body

```json
{
  "namespaceId": "<namespace-id>",
  "name": "my-agent",
  "image": "alpine/openclaw:2026.2.13",
  "chartType": "web",
  "port": 18789,
  "env": {
    "OPENROUTER_API_KEY": "<your-key (or use OPENAI_API_KEY / ANTHROPIC_API_KEY / GOOGLE_API_KEY)>",
    "AGENT_MODEL": "claude-sonnet-4-20250514",
    "AGENT_NAME": "my-agent",
    "TELEGRAM_BOT_TOKEN": "Optional — Telegram bot token",
    "AGENT_DESCRIPTION": "Optional description",
    "AGENT_SYSTEM_PROMPT": "Optional system prompt"
  }
}
```
