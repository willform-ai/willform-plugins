---
name: willform-deploy
description: Deploy containers to Kubernetes via Willform Agent REST API
---

# Willform Deploy Skill

Deploy containers to Kubernetes via the Willform Agent REST API.

## Prerequisites

- API key configured via `/wf-setup` (stored in `~/.claude/willform-plugins.local.md`)
- Docker image accessible (public registry or private with imagePullSecretName)
- `curl` and `jq` available in shell

## Workflow

All API calls use the shared helper. Load it at the start of any bash block:

```bash
source scripts/wf-api.sh && wf_load_config
```

### Step 1: Create Namespace

Every deployment lives inside a namespace. Create one first:

```bash
RESULT=$(wf_post "/api/namespaces" '{"name":"my-project","allocatedCores":1,"allocatedMemoryGb":2}')
NAMESPACE_ID=$(wf_json_field "$RESULT" "data.id")
```

`allocatedCores` (1-32) and `allocatedMemoryGb` (1-128) are required. These set the K8s ResourceQuota and determine billing.

### Step 2: Deploy

```bash
RESULT=$(wf_post "/api/deploy" "{
  \"namespaceId\": \"${NAMESPACE_ID}\",
  \"name\": \"my-app\",
  \"image\": \"nginx:latest\",
  \"chartType\": \"web\",
  \"port\": 80
}")
DEPLOYMENT_ID=$(wf_json_field "$RESULT" "data.deploymentId")
```

### Step 3: Expose Domain

Domain assignment is always a separate post-deploy action. The default domain is `{name}-{shortId}.willform.ai`.

```bash
RESULT=$(wf_post "/api/deploy/${DEPLOYMENT_ID}/expose")
DOMAIN=$(wf_json_field "$RESULT" "data.hostname")
```

For custom domains, use `POST /api/domains` with a hostname and CNAME it to `custom.willform.ai`.

### Step 4: Check Status

```bash
RESULT=$(wf_get "/api/deploy/${DEPLOYMENT_ID}")
STATUS=$(wf_json_field "$RESULT" "data.status")
```

Poll until `status` is `"running"` or a terminal state (`"failed"`).

## Chart Types

Nine workload types are supported:

| Chart Type    | K8s Resource   | Description                                         |
|---------------|----------------|-----------------------------------------------------|
| `web`         | Deployment     | HTTP service with optional HPA, Cloudflare ingress  |
| `database`    | StatefulSet    | Persistent storage, headless Service (PostgreSQL, MySQL, MongoDB) |
| `queue`       | StatefulSet    | Message brokers (Kafka, RabbitMQ, NATS)             |
| `cache`       | StatefulSet    | Caching layers (Redis, Memcached)                   |
| `storage`     | StatefulSet    | Object storage (MinIO, SeaweedFS)                   |
| `worker`      | Deployment     | Background processing, no Service/ingress, egress-only networking |
| `cronjob`     | CronJob        | Scheduled tasks, requires `chartConfig.schedule`    |
| `job`         | Job            | One-time batch execution                            |
| `static-site` | Deployment     | Lightweight static file serving with auto domain    |

### Chart-specific fields

- `cronjob` requires `chartConfig: { schedule: "*/5 * * * *" }` (cron expression)
- `database`/`queue`/`cache`/`storage` accept `volume: { size: "10Gi", mountPath: "/data" }`
- `web`/`static-site` support `healthCheckPath` (e.g., `"/health"`)

## Domain

- Default domain: `{name}-{shortId}.willform.ai` — assigned via `POST /api/deploy/{id}/expose`
- Custom domain: `POST /api/domains` with `{ deploymentId, hostname }` — CNAME to `custom.willform.ai` for SSL
- Domain assignment is always a separate action after deployment creation

## Deployment Body Reference

```json
{
  "namespaceId": "uuid",
  "name": "my-app",
  "image": "nginx:latest",
  "chartType": "web",
  "port": 80,
  "env": { "KEY": "value" },
  "replicas": 1,
  "volume": { "size": "10Gi", "mountPath": "/data" },
  "healthCheckPath": "/health",
  "fsGroup": 1000,
  "imagePullSecretName": "my-registry-secret",
  "chartConfig": { "schedule": "*/5 * * * *" }
}
```

Only `namespaceId`, `name`, and `image` are required. All other fields are optional.

## Error Handling

- HTTP 401: API key invalid or missing. Run `/wf-setup` to reconfigure.
- HTTP 402: Insufficient credits. Top up via dashboard or deposit.
- HTTP 404: Resource not found. Verify the namespace/deployment ID.
- HTTP 409: Name conflict. A namespace or deployment with that name already exists.
- HTTP 422: Validation error. Check required fields and chart-specific constraints.
- HTTP 500: Server error. Retry once, then check `/api/health`.

All API responses are wrapped in `{ success: boolean, data?: T, error?: string }`. Check `success` before accessing `data`.
