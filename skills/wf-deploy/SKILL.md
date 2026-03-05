---
name: wf-deploy
description: Deploy a container to Willform Agent with interactive configuration
allowed-tools: Bash, Read, Write, AskUserQuestion
user-invocable: true
---

# /wf-deploy -- Deploy Container to Willform

## Goal

Deploy any container image to Willform Agent. Walks the user through configuration (name, image, chart type, resources), runs preflight checks, creates the deployment, and exposes it if applicable.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

Follow these steps in order. Stop and report to the user if any step fails.

### Step 1: Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### Step 2: Gather deployment configuration

Use AskUserQuestion to collect the following. If any value was provided as an argument (`$ARGUMENTS`), use it and skip that question.

1. **App name** (required): Lowercase alphanumeric + hyphens, 1-63 chars. Suggest a name based on the current directory if no argument given.

2. **Container image** (required): Full image reference (e.g., `nginx:latest`, `ghcr.io/org/repo:tag`).
   - If the user wants to build from source, suggest running `/wf-build-push` first to build and push the image.
   - If the image is from a private registry, ask for registry credentials:
     - `server` (e.g., `ghcr.io`, `https://index.docker.io/v1/`)
     - `username`
     - `password` / token

3. **Chart type** (required): Ask the user to choose one:
   - **web** (Recommended) — HTTP service with external access
   - **worker** — Background process, no external access
   - **database** — Persistent storage, internal access only
   - **cronjob** — Scheduled task
   - Other types: `queue`, `cache`, `storage`, `job`, `static-site`

4. **Port** (conditional): Required for `web`, `database`, `queue`, `cache`, `storage`, `static-site`. Skip for `worker`, `cronjob`, `job`. Suggest common defaults:
   - web: 3000, 8080
   - database: 5432 (Postgres), 3306 (MySQL), 27017 (MongoDB)
   - cache: 6379 (Redis)
   - queue: 5672 (RabbitMQ)

5. **Environment variables** (optional): Key=value pairs. Ask if the user wants to add any. Accept multiline input.

6. **Volume** (conditional):
   - Required for `database` chart type (suggest 10GB, mount at `/data`)
   - Optional for other types
   - Ask for size (GB) and mount path

7. **Schedule** (conditional): Required for `cronjob` type only. Cron expression (e.g., `0 * * * *` for hourly).

8. **Health check path** (optional, for web/static-site): Suggest `/` or `/health`. Set to `null` if the container doesn't serve HTTP health checks.

Show a summary of the configuration and ask the user to confirm before proceeding.

### Step 3: Select or create namespace

List existing namespaces:

```bash
response=$(wf_get "/api/namespaces")
```

Parse the `data` array. For each namespace, show: `name`, `status`, remaining CPU/memory.

- If namespaces exist, ask the user to select one or create a new one.
- If creating a new namespace, ask for name and resource allocation (default: 2 cores, 4GB memory):

```bash
ns_body=$(jq -n --arg name "$NS_NAME" --argjson cores "$CORES" --argjson mem "$MEMORY" \
  '{name: $name, allocatedCores: $cores, allocatedMemoryGb: $mem}')
NS_RESULT=$(wf_post "/api/namespaces" "$ns_body")
NAMESPACE_ID=$(wf_json_field "$NS_RESULT" "data.id")
```

### Step 4: Run preflight check

Preflight uses `wf_mcp` (MCP JSON-RPC, no REST equivalent):

```bash
PREFLIGHT_ARGS=$(jq -n \
  --arg nsId "$NAMESPACE_ID" \
  --arg image "$IMAGE" \
  --arg chartType "$CHART_TYPE" \
  --arg name "$APP_NAME" \
  --argjson volumeSizeGb "${VOLUME_SIZE:-0}" \
  --argjson replicas 1 \
  '{namespaceId: $nsId, image: $image, chartType: $chartType, name: $name, volumeSizeGb: $volumeSizeGb, replicas: $replicas}')

# Add optional fields
if [[ -n "${REGISTRY_AUTH:-}" ]]; then
  PREFLIGHT_ARGS=$(echo "$PREFLIGHT_ARGS" | jq --argjson auth "$REGISTRY_AUTH" '. + {registryAuth: $auth}')
fi
if [[ -n "${HEALTH_CHECK:-}" ]]; then
  PREFLIGHT_ARGS=$(echo "$PREFLIGHT_ARGS" | jq --arg hc "$HEALTH_CHECK" '. + {healthCheckPath: $hc}')
fi

response=$(wf_mcp "deploy_preflight" "$PREFLIGHT_ARGS")
```

Parse the response JSON. The object contains:
- `canDeploy` (boolean): If `false`, show errors and stop
- `errors` (array): Each has `code`, `message`, and optional `suggestion`
- `warnings` (array): Show them and ask the user whether to proceed
- `costEstimate` (object): `hourly` and `monthly` strings — display to user
- `quotaHeadroom` (object): `cpuRemaining` — warn if low

### Step 5: Deploy

Build the deploy body using the gathered configuration:

```bash
DEPLOY_BODY=$(jq -n \
  --arg nsId "$NAMESPACE_ID" \
  --arg name "$APP_NAME" \
  --arg image "$IMAGE" \
  --arg chartType "$CHART_TYPE" \
  --argjson port "${PORT:-null}" \
  --argjson env "$ENV_JSON" \
  --argjson volumeSizeGb "${VOLUME_SIZE:-0}" \
  --arg volumeMountPath "${VOLUME_PATH:-/data}" \
  '{
    namespaceId: $nsId,
    name: $name,
    image: $image,
    chartType: $chartType,
    port: $port,
    env: $env,
    volumeSizeGb: $volumeSizeGb,
    volumeMountPath: $volumeMountPath
  }')

# Add optional fields
if [[ -n "${REGISTRY_AUTH:-}" ]]; then
  DEPLOY_BODY=$(echo "$DEPLOY_BODY" | jq --argjson auth "$REGISTRY_AUTH" '. + {registryAuth: $auth}')
fi
if [[ -n "${HEALTH_CHECK:-}" ]]; then
  DEPLOY_BODY=$(echo "$DEPLOY_BODY" | jq --arg hc "$HEALTH_CHECK" '. + {healthCheckPath: $hc}')
fi
if [[ -n "${SCHEDULE:-}" ]]; then
  DEPLOY_BODY=$(echo "$DEPLOY_BODY" | jq --arg s "$SCHEDULE" '. + {schedule: $s}')
fi

response=$(wf_post "/api/deploy" "$DEPLOY_BODY")
DEPLOYMENT_ID=$(wf_json_field "$response" "data.deploymentId")
```

If deploy fails, show the error and stop.

### Step 6: Poll for readiness

Wait for the deployment to become ready (max 120 seconds):

```bash
for i in $(seq 1 24); do
  RESULT=$(wf_get "/api/deploy/${DEPLOYMENT_ID}")
  STATUS=$(wf_json_field "$RESULT" "data.status")
  if [[ "$STATUS" == "running" ]]; then break; fi
  if [[ "$STATUS" == "failed" ]]; then
    echo "Deployment failed."
    wf_get "/api/deploy/${DEPLOYMENT_ID}/logs" 2>/dev/null || true
    break
  fi
  sleep 5
done
```

### Step 7: Expose (for web and static-site)

If the chart type is `web` or `static-site`, expose the deployment to get a public URL:

```bash
RESULT=$(wf_post "/api/deploy/${DEPLOYMENT_ID}/expose")
DOMAIN=$(wf_json_field "$RESULT" "data.hostname")
```

### Step 8: Report result

**On success:**

```
Deployment created successfully.

  Name:      {app_name}
  Status:    {status}
  Image:     {image}
  Type:      {chart_type}
  URL:       https://{domain}  (if exposed)
  Cost:      {hourly}/hr ({monthly}/mo estimated)

Next steps:
  /wf-status {app_name}    Check deployment status
  /wf-logs {app_name}      View container logs
  /wf-monitor {app_name}   Health check and diagnostics
```

**On failure or timeout:**

```
Deployment did not reach running state.

  Name:      {app_name}
  Status:    {status}

Troubleshooting:
  /wf-logs {app_name}       View container logs
  /wf-diagnose {app_name}   Run diagnostics
```

## Common Deployments

When the user asks to deploy a specific application type, guide them with appropriate defaults:

| Application | Image | Type | Port | Notes |
|---|---|---|---|---|
| Next.js app | Custom (use /wf-build-push) | web | 3000 | Needs `--platform linux/amd64` |
| PostgreSQL | `postgres:16` | database | 5432 | Volume required, set `POSTGRES_PASSWORD` env |
| Redis | `redis:7` | cache | 6379 | |
| Nginx | `nginx:latest` | web | 80 | |
| Python API | Custom (use /wf-build-push) | web | 8000 | |
| Background worker | Custom | worker | — | No port needed |
| Cron job | Custom | cronjob | — | Needs schedule expression |

## Error Handling

- If API returns 401, suggest `/wf-setup` to reconfigure API key
- If API returns 402, show insufficient funds error and suggest `/wf-credits` to top up
- If preflight fails, show all errors clearly and suggest fixes
- If deploy fails with image pull error, suggest checking image name and registry auth
- If deploy times out after 120s, suggest `/wf-logs` to check what's happening
