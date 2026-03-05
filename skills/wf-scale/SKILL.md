---
name: wf-scale
description: Scale, stop, restart, or delete deployments on Willform Agent
allowed-tools: Bash, Read, AskUserQuestion
user-invocable: true
---

# /wf-scale -- Scale & Manage Deployments

## Goal

Day-2 operations for deployments: scale replicas, stop, restart, or delete a deployment on Willform Agent.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

### Step 1: Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### Step 2: Determine action

If arguments are provided (`$ARGUMENTS`), parse them:
- `<name> scale <N>` → scale to N replicas
- `<name> stop` → stop the deployment
- `<name> restart` → restart the deployment
- `<name> delete` → delete the deployment
- `<name>` alone → show current scale info and ask what to do

If no argument, list deployments and use AskUserQuestion to select one and an action:
- **Scale replicas** — Change the number of running instances (1-10)
- **Restart** — Restart all pods (rolling restart)
- **Stop** — Scale to 0, stop billing for compute
- **Delete** — Permanently remove the deployment

### Step 3: Resolve deployment

Find the deployment by name or UUID via `GET /api/deploy`.

### Step 4: Execute action

#### Scale

```bash
body=$(jq -n --argjson replicas "$REPLICAS" '{replicas: $replicas}')
response=$(wf_post "/api/deploy/${DEPLOY_ID}/scale" "$body")
```

#### Stop

```bash
response=$(wf_post "/api/deploy/${DEPLOY_ID}/stop")
```

#### Restart

```bash
response=$(wf_post "/api/deploy/${DEPLOY_ID}/restart")
```

#### Delete

**Warn the user**: this permanently removes the deployment, its volumes, and domain. Require explicit confirmation.

```bash
response=$(wf_delete "/api/deploy/${DEPLOY_ID}")
```

### Step 5: Report result

Show the action result and current deployment state.

- After scale: show new replica count and cost impact
- After stop: note that compute billing stops but storage continues
- After restart: poll for readiness (max 60s)
- After delete: confirm removal

## Error Handling

- If API returns 401, suggest `/wf-setup`
- If API returns 402, suggest `/wf-credits` to top up (scaling up requires runway)
- If deployment not found, list available deployments
