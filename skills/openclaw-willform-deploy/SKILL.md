---
name: willform-deploy
description: Deploy containers to Willform cloud platform via natural language
metadata:
  openclaw:
    requires:
      env:
        - WF_API_KEY
      bins:
        - curl
        - jq
    primaryEnv: WF_API_KEY
---

# willform-deploy

Deploy and manage containers on Willform cloud using natural language.

## Description

This skill lets you deploy applications to Willform Agent, a Kubernetes-based cloud platform. It uses Willform's MCP endpoint (`/api/mcp`) to call 42 tools via a single curl pattern. No SDK or special client needed — just curl and jq.

## Setup

Set the `WF_API_KEY` environment variable with your Willform API key (starts with `wf_sk_`).

Get one at https://agent.willform.ai > Settings > API Keys.

## Core Function

All Willform operations use this single bash function. Define it at the start of every session:

```bash
wf_mcp() {
  local tool="$1" args="${2:-\{\}}"
  local body
  body=$(jq -n --arg t "$tool" --argjson a "$args" \
    '{jsonrpc:"2.0",method:"tools/call",params:{name:$t,arguments:$a},id:1}')
  local raw
  raw=$(curl -s -X POST https://agent.willform.ai/api/mcp \
    -H "Authorization: Bearer $WF_API_KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d "$body" 2>/dev/null)
  local sse
  sse=$(echo "$raw" | sed -n 's/^data: //p' | head -1)
  if [ -z "$sse" ]; then sse="$raw"; fi
  echo "$sse" | jq -r '.result.content[0].text // empty' 2>/dev/null
}
```

## Deployment Workflow

When a user asks to deploy something, follow these steps in order.

### Step 1: Create or select a namespace

Every deployment lives in a namespace. List existing ones or create a new one.

**List namespaces:**
```bash
wf_mcp namespace_list '{}'
```

**Create namespace** (if needed):
```bash
wf_mcp namespace_create '{"name":"my-project","allocatedCores":2}'
```

Save the `id` field from the response as NAMESPACE_ID.

### Step 2: Generate a deployment plan

Use `deploy_plan` to translate the user's natural language request into ordered steps. Pass the namespace ID and the user's description.

```bash
wf_mcp deploy_plan "{\"namespaceId\":\"$NAMESPACE_ID\",\"description\":\"USER_REQUEST_HERE\"}"
```

The response contains `.data.plan.steps` — an array of ordered deployment steps. Each step has:
- `order`: execution sequence number
- `action`: the MCP tool to call (`deploy_create` or `deploy_expose`)
- `description`: human-readable step description
- `params`: the exact parameters to pass to the tool
- `waitFor`: if set to `"running"`, poll status before proceeding to next step
- `outputVars`: environment variables produced by this step (e.g., DATABASE_URL) — inject into later steps

Also check `.data.plan.warnings` for important notices (e.g., change default passwords).

### Step 3: Execute the plan

Run each step in order using `wf_mcp`:

```bash
wf_mcp deploy_create '{ ...params from step... }'
```

**After each step with `waitFor: "running"`:**

Poll the deployment status until it reaches "running":
```bash
wf_mcp deploy_status '{"deploymentId":"DEPLOY_ID"}'
```
Check `.data.status` — poll every 10 seconds, max 3 minutes.

**Variable substitution:**

If a step has `outputVars` (e.g., `DATABASE_URL`), inject the actual connection string into the `env` field of later steps that reference it. Replace `CHANGE_ME` in passwords with a secure value.

### Step 4: Expose (if the plan includes deploy_expose)

The plan's last step for web/static-site apps is `deploy_expose`. The `params` only contain `protocol`, so you need to add the deployment ID:

```bash
wf_mcp deploy_expose '{"deploymentId":"WEB_DEPLOY_ID"}'
```

The response includes `hostname` — this is the public URL.

### Step 5: Report results

Summarize what was deployed:
- Namespace name and ID
- Each deployment: name, image, status, type
- Public URL (if exposed)
- Warnings from the plan (especially password changes)

## Quick Deploy Examples

**Single container (no plan needed):**

User: "nginx on port 80"
```bash
NSID=$(wf_mcp namespace_create '{"name":"demo"}' | jq -r '.data.id')
DID=$(wf_mcp deploy_create "{\"namespaceId\":\"$NSID\",\"name\":\"nginx\",\"image\":\"nginx:alpine\",\"chartType\":\"web\",\"port\":80}" | jq -r '.data.deploymentId')
wf_mcp deploy_expose "{\"deploymentId\":\"$DID\"}"
```

**Fullstack with dependencies (use deploy_plan):**

User: "PostgreSQL database + Express API"
```bash
# 1. Create namespace
NSID=$(wf_mcp namespace_create '{"name":"my-api"}' | jq -r '.data.id')
# 2. Get plan
PLAN=$(wf_mcp deploy_plan "{\"namespaceId\":\"$NSID\",\"description\":\"Express API with PostgreSQL database\"}")
# 3. Execute each step from $PLAN in order
```

## Available Tools Reference

These are the most useful MCP tools. Call any of them with `wf_mcp`:

| Tool | Description |
|------|-------------|
| `namespace_list` | List all namespaces |
| `namespace_create` | Create a namespace |
| `deploy_plan` | Generate deployment plan from natural language |
| `deploy_create` | Create a deployment |
| `deploy_status` | Check deployment status |
| `deploy_list` | List deployments in a namespace |
| `deploy_expose` | Expose deployment with public domain |
| `deploy_unexpose` | Remove public domain |
| `deploy_logs` | View container logs |
| `deploy_events` | View deployment events |
| `deploy_scale` | Scale replicas |
| `deploy_update_env` | Update environment variables |
| `deploy_stop` | Stop a deployment |
| `deploy_restart` | Restart a deployment |
| `deploy_delete` | Delete a deployment |
| `domain_add` | Add custom domain |
| `credit_balance` | Check credit balance |
| `billing_estimate` | Estimate deployment cost |
| `build_upload` | Prepare source code upload |
| `build_start` | Start image build |
| `build_status` | Check build progress |
| `template_list` | List available templates |
| `template_deploy` | Deploy from template |

## Building from Source

When the user has source code to deploy (not a pre-built image):

1. **Prepare upload:**
```bash
wf_mcp build_upload "{\"namespaceId\":\"$NSID\",\"imageName\":\"my-app\",\"fileName\":\"source.tar.gz\"}"
```
Save `buildId` and `uploadUrl` from the response.

2. **Package and upload source:**
```bash
cd /path/to/source && tar czf /tmp/source.tar.gz .
curl -s -X PUT "$UPLOAD_URL" -H "Content-Type: application/gzip" --data-binary @/tmp/source.tar.gz
```

3. **Start build:**
```bash
wf_mcp build_start "{\"namespaceId\":\"$NSID\",\"buildId\":\"$BUILD_ID\",\"tag\":\"v1\"}"
```

4. **Poll build status** until `status` is `"success"`:
```bash
wf_mcp build_status "{\"namespaceId\":\"$NSID\",\"buildId\":\"$BUILD_ID\"}"
```
Save `imageUri` from the response.

5. **Deploy with built image:**
```bash
wf_mcp deploy_create "{\"namespaceId\":\"$NSID\",\"name\":\"my-app\",\"image\":\"$IMAGE_URI\",\"chartType\":\"web\",\"port\":3000}"
```

## Monitoring and Management

```bash
# Check all deployments
wf_mcp deploy_list '{"namespaceId":"NSID"}'

# View logs
wf_mcp deploy_logs '{"deploymentId":"DID","lines":100}'

# Check balance
wf_mcp credit_balance '{}'

# Estimate cost before deploying
wf_mcp billing_estimate '{"chartType":"web","cores":0.5,"memoryGb":0.5}'
```

## Error Handling

- **401 Unauthorized**: API key invalid or expired. Get a new one at https://agent.willform.ai
- **402 Insufficient funds**: Check balance with `credit_balance`, top up at https://agent.willform.ai
- **INSUFFICIENT_RUNWAY**: Need at least 2 hours of runway (balance / burn rate >= 2h)
- **Image pull error**: Check image name and registry auth
- **Deployment timeout**: Check logs with `deploy_logs` and events with `deploy_events`

## Pricing

- Compute: $0.04/core/hour
- Memory: $0.01/GB/hour
- Storage: $0.00018/GB/hour
