---
name: wf-env
description: Manage environment variables for deployments on Willform
allowed-tools: Bash, Read, AskUserQuestion
user-invocable: true
---

# /wf-env -- Manage Environment Variables

## Goal

View and update environment variables for a deployment on Willform. Supports merge (add/update without removing existing) and replace (overwrite all) modes.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

### Step 1: Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### Step 2: Resolve deployment

A deployment name must be provided as an argument (`$ARGUMENTS`). If none, list deployments and ask the user to select one.

Resolve to deployment ID via `GET /api/deploy`.

### Step 3: Determine action

Use AskUserQuestion:
- **View env vars** — Show current environment variables
- **Set env vars** — Add or update variables (merge mode)
- **Replace all env vars** — Overwrite all variables

### Step 4: Execute action

#### View env vars

```bash
response=$(wf_get "/api/deploy/${DEPLOY_ID}")
env_vars=$(echo "$response" | jq '.data.env // {}')
```

Display in a readable format with values **redacted by default**:

```
Environment Variables: {deployment_name}

  DATABASE_URL=<redacted>
  NODE_ENV=<redacted>
  PORT=<redacted>
```

If no env vars are set, show "(none)".

Do **not** print raw secret values into the chat/session transcript by default. If the user explicitly needs a value revealed, ask for confirmation first and reveal only the requested key.

#### Set env vars (merge)

Ask the user for key=value pairs. Build the env JSON object.

This operation uses `wf_mcp` because `deploy_update_env` has no REST equivalent:

```bash
ENV_JSON=$(jq -n --argjson env "$USER_ENV" '$env')
wf_mcp "deploy_update_env" "{\"deploymentId\":\"${DEPLOY_ID}\",\"env\":${ENV_JSON},\"merge\":true}"
```

**Note**: Updating env vars triggers a rolling restart of the deployment.

#### Replace all env vars

Same as merge but with `"merge":false`:

```bash
wf_mcp "deploy_update_env" "{\"deploymentId\":\"${DEPLOY_ID}\",\"env\":${ENV_JSON},\"merge\":false}"
```

**Warn the user** that this will remove all existing env vars not included in the new set.

### Step 5: Report result

Show the updated env var **keys** (not raw values) and note that the deployment will restart.

Suggest `/wf-status <name>` to verify the restart completes.

## Error Handling

- If API returns 401, suggest `/wf-setup`
- If deployment not found, list available deployments
- If MCP call fails, show the error and suggest checking the deployment status
