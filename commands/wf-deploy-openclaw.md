---
allowed-tools: Bash, Read, Write, AskUserQuestion
description: Deploy an OpenClaw AI agent to Willform Agent
user-invocable: true
---

# /wf-deploy-openclaw — Deploy OpenClaw Agent

## Goal

Deploy an OpenClaw AI agent runtime to Willform Agent with minimal user input.

## Steps

### 1. Load API config

```bash
source scripts/wf-api.sh && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### 2. Gather user input

Use AskUserQuestion for each:

1. **Agent name** (required): Used as deployment name and `AGENT_NAME` env var. Must be lowercase alphanumeric with hyphens, no spaces.

2. **OPENROUTER_API_KEY** (required): Their OpenRouter API key for LLM access. Starts with `sk-or-`.

3. **Agent model** (optional, default: `claude-sonnet-4-20250514`): The model identifier to use.

4. **Agent description** (optional): Short description for `AGENT_DESCRIPTION`.

5. **Namespace**: Ask whether to create a new namespace or use an existing one.
   - If existing: list namespaces via `wf_get "/api/namespaces"` and let user pick
   - If new: ask for namespace name (default: same as agent name)

### 3. Create namespace (if needed)

```bash
RESULT=$(wf_post "/api/namespaces" "{\"name\":\"${NAMESPACE_NAME}\"}")
NAMESPACE_ID=$(wf_json_field "$RESULT" "data.id")
SHORT_ID=$(wf_json_field "$RESULT" "data.shortId")
```

If using an existing namespace, extract `NAMESPACE_ID` and `SHORT_ID` from the selected namespace.

### 4. Deploy OpenClaw

Build the env JSON. Only include optional fields if the user provided them.

```bash
ENV_JSON="{\"OPENROUTER_API_KEY\":\"${API_KEY}\",\"AGENT_MODEL\":\"${MODEL}\",\"AGENT_NAME\":\"${AGENT_NAME}\"}"
# Append AGENT_DESCRIPTION and AGENT_SYSTEM_PROMPT if provided

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

### 5. Expose default domain

```bash
RESULT=$(wf_post "/api/deploy/${DEPLOYMENT_ID}/expose")
DOMAIN=$(wf_json_field "$RESULT" "data.hostname")
```

### 6. Poll for readiness

Poll `GET /api/deploy/{id}` every 5 seconds, max 120 seconds (24 attempts):

```bash
for i in $(seq 1 24); do
  RESULT=$(wf_get "/api/deploy/${DEPLOYMENT_ID}")
  STATUS=$(wf_json_field "$RESULT" "data.status")
  if [[ "$STATUS" == "running" ]]; then
    break
  elif [[ "$STATUS" == "failed" ]]; then
    echo "Deployment failed." >&2
    # Show logs for debugging
    wf_get "/api/deploy/${DEPLOYMENT_ID}/logs"
    break
  fi
  sleep 5
done
```

### 7. Report result

On success, display:

```
OpenClaw agent deployed successfully.

  Name:   {agent_name}
  URL:    https://{domain}
  Status: running

Use /wf-status to check deployment health.
Use /wf-logs to view agent logs.
```

On failure or timeout, display the error and suggest checking logs with `wf_get "/api/deploy/${DEPLOYMENT_ID}/logs"`.
