---
name: wf-apm
description: Deploy MCP servers declared in apm.yml to Willform Agent (Microsoft APM integration)
allowed-tools: Bash, Read, Write, AskUserQuestion
user-invocable: true
---

# /wf-apm — Deploy MCP Servers from apm.yml

## Goal

Parse an `apm.yml` manifest (Microsoft Agent Package Manager format) and deploy each self-defined MCP server to Willform Agent as a `web` chart deployment. Returns the live MCP endpoint URLs.

Supports:
- `--apm-file <path>` — path to apm.yml (default: `./apm.yml`)
- `--namespace <name-or-id>` — skip interactive namespace selection (useful in agent/CI contexts)
- `--dry-run` — parse and show what would be deployed, without making any API calls

**v1 scope:** Only `dependencies.mcp[]` entries where `registry: false` and `url` is present (streamable-http, sse, or http transport). Registry-backed entries (e.g. `io.github.xxx/xxx`) are skipped with a clear warning — those are locally executed servers, not Willform-hosted. Stdio-only entries (no `url`) are also skipped.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

Follow these steps in order. Stop and report to the user if any step fails.

### Step 1: Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### Step 2: Parse arguments

From `$ARGUMENTS`, extract:
- `APM_FILE` — value of `--apm-file <path>`, default `./apm.yml`
- `DRY_RUN` — `true` if `--dry-run` flag is present, otherwise `false`
- `NS_ARG` — value of `--namespace <name-or-id>`, default empty (interactive selection)

```bash
APM_FILE="./apm.yml"
DRY_RUN="false"
NS_ARG=""

args="$ARGUMENTS"
while [[ -n "$args" ]]; do
  case "$args" in
    --apm-file*)
      APM_FILE=$(echo "$args" | sed 's/--apm-file[= ]\([^ ]*\).*/\1/')
      args=$(echo "$args" | sed 's/--apm-file[= ][^ ]*//')
      ;;
    --namespace*)
      NS_ARG=$(echo "$args" | sed 's/--namespace[= ]\([^ ]*\).*/\1/')
      args=$(echo "$args" | sed 's/--namespace[= ][^ ]*//')
      ;;
    *--dry-run*)
      DRY_RUN="true"
      args=$(echo "$args" | sed 's/--dry-run//')
      ;;
  esac
  args=$(echo "$args" | xargs)  # trim whitespace
done
```

### Step 3: Read and parse apm.yml

```bash
if [[ ! -f "$APM_FILE" ]]; then
  echo "Error: apm.yml not found at '$APM_FILE'. Use --apm-file <path> to specify a custom location."
  exit 1
fi

APM_CONTENT=$(cat "$APM_FILE")
```

Validate required fields:
```bash
APM_NAME=$(echo "$APM_CONTENT" | python3 -c "import sys,yaml; d=yaml.safe_load(sys.stdin); print(d.get('name',''))")
APM_VERSION=$(echo "$APM_CONTENT" | python3 -c "import sys,yaml; d=yaml.safe_load(sys.stdin); print(d.get('version',''))")

if [[ -z "$APM_NAME" || -z "$APM_VERSION" ]]; then
  echo "Error: apm.yml must have 'name' and 'version' fields."
  exit 1
fi
```

Extract `dependencies.mcp` entries and filter to deployable ones:

```bash
MCP_ENTRIES=$(echo "$APM_CONTENT" | python3 -c "
import sys, yaml, json
d = yaml.safe_load(sys.stdin)
mcp = d.get('dependencies', {}).get('mcp', []) or []
results = []
skipped = []
for entry in mcp:
    if isinstance(entry, str):
        skipped.append({'name': entry, 'reason': 'registry-backed servers are not deployable (local execution only)'})
        continue
    if not isinstance(entry, dict):
        continue
    name = entry.get('name', '')
    registry = entry.get('registry', True)
    url = entry.get('url', '')
    transport = entry.get('transport', '')
    env = entry.get('env', {}) or {}

    if registry is not False:
        skipped.append({'name': name, 'reason': 'registry-backed servers are not deployable (local execution only)'})
        continue

    if not url:
        skipped.append({'name': name, 'reason': 'stdio transport not supported — only http/sse/streamable-http with a url can be deployed'})
        continue

    results.append({'name': name, 'url': url, 'env': env, 'transport': transport})

print(json.dumps({'deployable': results, 'skipped': skipped}))
" 2>/dev/null)

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to parse apm.yml. Ensure python3 and PyYAML are installed (pip install pyyaml)."
  exit 1
fi

DEPLOYABLE=$(echo "$MCP_ENTRIES" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d['deployable']))")
SKIPPED=$(echo "$MCP_ENTRIES" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d['skipped']))")
DEPLOY_COUNT=$(echo "$DEPLOYABLE" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
SKIP_COUNT=$(echo "$SKIPPED" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
```

Show summary:

```
APM manifest: {APM_NAME} v{APM_VERSION}

  MCP servers found:    {DEPLOY_COUNT + SKIP_COUNT}
  Deployable:           {DEPLOY_COUNT}
  Skipped:              {SKIP_COUNT}
```

For each skipped entry, print:
```
  ⚠ Skipping {name} — {reason}
```

If `DEPLOY_COUNT` is 0:
```
No deployable MCP servers found in {APM_FILE}.

Only self-defined servers with a url (transport: http, sse, or streamable-http) can be deployed.
Registry-backed servers (e.g. io.github.xxx/xxx) run locally via the APM client — Willform does not host them.
```
Stop.

If `DRY_RUN` is `true`, print:
```
Dry run — the following would be deployed:

{for each entry in DEPLOYABLE}
  • {name}
    Current URL: {url}
    Transport:   {transport}
    Env vars:    {comma-separated keys, or "(none)"}
```
Stop without making any API calls.

### Step 4: Collect Docker images

Willform deploys container images. For each entry in `DEPLOYABLE`, ask for the Docker image to deploy:

```
use AskUserQuestion: "MCP server '{name}' (currently at {url}) — what Docker image should Willform deploy?
Examples: ghcr.io/myorg/my-mcp-server:latest, registry.willform.ai/myns/my-server:v1.0
(Run /wf-build-push first if you need to build and push an image)"
```

Store the result as `ENTRY_IMAGE` for that entry.

If the user provides an empty value or skips, skip that entry and add it to the skipped list.

### Step 5: Resolve namespace

If `--namespace <name-or-id>` was provided via `NS_ARG`, resolve it without prompting:

```bash
if [[ -n "$NS_ARG" ]]; then
  NS_RESPONSE=$(wf_get "/api/namespaces")
  NAMESPACE_ID=$(echo "$NS_RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
target = '${NS_ARG}'.lower()
for ns in d.get('data', []):
    if ns.get('id') == target or ns.get('name', '').lower() == target:
        print(ns['id'])
        break
" 2>/dev/null)
  if [[ -z "$NAMESPACE_ID" ]]; then
    echo "Error: namespace '${NS_ARG}' not found. Run /wf-namespace to list available namespaces."
    exit 1
  fi
else
  # Interactive selection
  NS_RESPONSE=$(wf_get "/api/namespaces")
  # Parse the data array. For each namespace, show: name, status, remaining CPU/memory.
  # Ask the user to select one or create a new one.
  # If creating a new namespace, ask for name and resource allocation (default: 2 cores, 4GB memory):
  ns_body=$(python3 -c "import json; print(json.dumps({'name': '${NS_NAME}', 'allocatedCores': ${CORES}, 'allocatedMemoryGb': ${MEMORY}}))")
  NS_RESULT=$(wf_post "/api/namespaces" "$ns_body")
  NAMESPACE_ID=$(wf_json_field "$NS_RESULT" "data.id")
fi
```

Tip: for non-interactive (agent/CI) use, pass `--namespace <name>` to skip the prompt.

### Step 6: Resolve placeholder env vars (interactive)

For each entry in `DEPLOYABLE`, inspect `env` values. If any value contains `${input:...}` or `${{secrets.*}}` patterns, prompt the user:

```
for each entry in DEPLOYABLE:
  for each KEY=VALUE in entry.env:
    if VALUE contains '${input:' or '${{secrets':
      use AskUserQuestion: "MCP server '{name}' needs env var '{KEY}'. Please enter the value:"
      replace placeholder with user-provided value
```

Plain values (no placeholder) are used as-is.

### Step 7: Deploy each MCP server

For each entry in `DEPLOYABLE` (with a confirmed `ENTRY_IMAGE`), check if a deployment with the same name already exists in the namespace:

```bash
EXISTING=$(wf_get "/api/deploy?namespaceId=${NAMESPACE_ID}")
EXISTING_ID=$(echo "$EXISTING" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for dep in d.get('data', []):
    if dep.get('name') == '${ENTRY_NAME}' and dep.get('status') != 'deleted':
        print(dep.get('id', ''))
        break
" 2>/dev/null)
```

**If no existing deployment** — run preflight then create:

```bash
PREFLIGHT_ARGS=$(python3 -c "import json; print(json.dumps({
  'namespaceId': '${NAMESPACE_ID}',
  'image': '${ENTRY_IMAGE}',
  'chartType': 'web',
  'name': '${ENTRY_NAME}',
  'volumeSizeGb': 0,
  'replicas': 1
}))")
PREFLIGHT=$(wf_mcp "deploy_preflight" "$PREFLIGHT_ARGS")
CAN_DEPLOY=$(echo "$PREFLIGHT" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('canDeploy', False))" 2>/dev/null)

if [[ "$CAN_DEPLOY" != "True" && "$CAN_DEPLOY" != "true" ]]; then
  ERRORS=$(echo "$PREFLIGHT" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); [print(f'  {e[\"code\"]}: {e[\"message\"]}') for e in d.get('errors',[])]" 2>/dev/null)
  echo "  ✗ {name}: preflight failed"
  echo "$ERRORS"
  # skip this entry, continue to next
fi

DEPLOY_BODY=$(python3 -c "
import json
body = {
  'namespaceId': '${NAMESPACE_ID}',
  'name': '${ENTRY_NAME}',
  'image': '${ENTRY_IMAGE}',
  'chartType': 'web',
  'port': 8080,
  'env': ${ENTRY_ENV_JSON},
  'healthCheckPath': None
}
print(json.dumps(body))
")
RESULT=$(wf_post "/api/deploy" "$DEPLOY_BODY")
DEPLOYMENT_ID=$(wf_json_field "$RESULT" "data.deploymentId")
echo "  → Deploying {name} (new)..."
```

**If existing deployment found** — update env vars and restart with new image:

```bash
wf_mcp "deploy_update_env" "$(python3 -c "import json; print(json.dumps({
  'deploymentId': '${EXISTING_ID}',
  'env': ${ENTRY_ENV_JSON},
  'merge': False
}))")"

wf_mcp "deploy_restart" "$(python3 -c "import json; print(json.dumps({
  'deploymentId': '${EXISTING_ID}',
  'image': '${ENTRY_IMAGE}'
}))")"

DEPLOYMENT_ID="$EXISTING_ID"
echo "  → Updating {name} (existing)..."
```

### Step 8: Poll for readiness

Poll ALL deployments (new AND update/restart) — image pull, container recreate, and healthcheck all take time regardless of whether it is a new deploy or a restart with a new image. Silent failures are possible without polling.

```bash
STATUS="unknown"
for i in $(seq 1 24); do
  POLL=$(wf_get "/api/deploy/${DEPLOYMENT_ID}")
  STATUS=$(wf_json_field "$POLL" "data.status")
  if [[ "$STATUS" == "running" ]]; then break; fi
  if [[ "$STATUS" == "failed" ]]; then
    echo "  ✗ {name}: deployment failed — run /wf-logs {name} to diagnose"
    break
  fi
  sleep 5
done
```

Max wait: 120s (24 × 5s). If still not running after timeout, report status and suggest `/wf-logs {name}`.

### Step 9: Expose (if not already exposed)

For each successfully running deployment, check if already exposed:

```bash
DEPLOY_INFO=$(wf_get "/api/deploy/${DEPLOYMENT_ID}")
HOSTNAME=$(wf_json_field "$DEPLOY_INFO" "data.hostname")

if [[ -z "$HOSTNAME" ]]; then
  EXPOSE_RESULT=$(wf_post "/api/deploy/${DEPLOYMENT_ID}/expose" "{}")
  HOSTNAME=$(wf_json_field "$EXPOSE_RESULT" "data.hostname")
fi

MCP_URL="https://${HOSTNAME}/mcp"
```

### Step 10: Report results

```
APM deployment complete.

  Deployed from: {APM_FILE}
  Namespace:     {namespace_name}

MCP Servers:

  ✓ {name}
    Image:  {image}
    URL:    https://{hostname}/mcp
    Status: running
    Cost:   ~$0.04/hr (1 core)

  ✗ {failed_name}
    Status: failed — run /wf-logs {failed_name}

Skipped ({SKIP_COUNT}):
  ⚠ {skipped_name} — {reason}

──────────────────────────────────────────────────
Update your apm.yml with the deployed endpoints:

  dependencies:
    mcp:
{for each successfully deployed entry}
      - name: {name}
        registry: false
        transport: streamable-http
        url: https://{hostname}/mcp

Next steps:
  /wf-status {name}    Check deployment status
  /wf-logs {name}      View container logs
  /wf-monitor {name}   Health diagnostics
```

## Error Handling

- `apm.yml` not found: show clear path + suggest `--apm-file` flag
- YAML parse error: suggest `pip install pyyaml`
- No deployable entries: explain registry-backed vs self-defined distinction; mention stdio limitation
- No Docker image provided for an entry: skip that entry, continue with others
- Preflight failed: show all errors per entry; skip that entry
- API 401: suggest `/wf-setup` to reconfigure API key
- API 402: insufficient funds — suggest `/wf-credits` to top up
- Deployment failed after poll timeout: suggest `/wf-logs {name}` and `/wf-diagnose {name}`
- Namespace quota exceeded: shown in preflight errors; suggest `/wf-namespace` to scale up
