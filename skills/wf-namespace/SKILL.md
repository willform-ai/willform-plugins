---
name: wf-namespace
description: Manage namespaces on Willform Agent
allowed-tools: Bash, Read, AskUserQuestion
user-invocable: true
---

# /wf-namespace -- Manage Namespaces

## Goal

List, create, update, or delete namespaces on Willform Agent. Namespaces are isolated resource pools that contain deployments.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

### Step 1: Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### Step 2: Determine action

If an argument is provided (`$ARGUMENTS`), interpret it:
- No argument or `list` → list all namespaces
- `create` → create a new namespace
- A name or UUID → show details for that namespace

If the action is ambiguous, use AskUserQuestion:
- **List namespaces** — Show all namespaces with status and resources
- **Create namespace** — Create a new namespace
- **Update namespace** — Change resource allocation
- **Delete namespace** — Remove a namespace and all its deployments

### Step 3: Execute action

#### List namespaces

```bash
response=$(wf_get "/api/namespaces")
```

Parse the `data` array and display:

```
Namespaces:
  NAME              STATUS    CPU     MEMORY    DEPLOYMENTS
  my-project        active    2/2     4/4 GB    3
  test-env          active    1/2     2/4 GB    1
```

#### Create namespace

Use AskUserQuestion to collect:
1. **Name** (required): Lowercase alphanumeric + hyphens
2. **CPU cores** (default: 2): Number of CPU cores to allocate
3. **Memory GB** (default: 4): Memory in GB to allocate

```bash
body=$(jq -n --arg name "$NAME" --argjson cores "$CORES" --argjson mem "$MEMORY" \
  '{name: $name, allocatedCores: $cores, allocatedMemoryGb: $mem}')
response=$(wf_post "/api/namespaces" "$body")
```

Show the created namespace ID and name.

#### Update namespace

Resolve namespace ID first (by name or UUID). Use AskUserQuestion to collect new resource values.

```bash
body=$(jq -n --argjson cores "$CORES" --argjson mem "$MEMORY" \
  '{allocatedCores: $cores, allocatedMemoryGb: $mem}')
response=$(wf_put "/api/namespaces/${NS_ID}" "$body")
```

#### Delete namespace

Resolve namespace ID. **Warn the user** that deleting a namespace will destroy all deployments within it. Require explicit confirmation.

```bash
response=$(wf_delete "/api/namespaces/${NS_ID}")
```

### Step 4: Report result

Show the action result and suggest next steps:
- After create: suggest `/wf-deploy` to deploy to the new namespace
- After list: suggest `/wf-namespace <name>` for details
- After delete: confirm deletion

## Error Handling

- If API returns 401, suggest `/wf-setup` to reconfigure API key
- If namespace not found, show available namespaces
- If delete fails due to active deployments, list them and suggest stopping first
