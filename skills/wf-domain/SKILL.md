---
name: wf-domain
description: Manage custom domains and external access on Willform Agent
allowed-tools: Bash, Read, AskUserQuestion
user-invocable: true
---

# /wf-domain -- Manage Domains

## Goal

Expose deployments, add custom domains, verify DNS, and manage external access on Willform Agent.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

### Step 1: Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### Step 2: Determine action

If an argument is provided (`$ARGUMENTS`), treat it as a deployment name and show its domain status.

Otherwise, use AskUserQuestion:
- **Expose deployment** — Get a `*.willform.ai` subdomain
- **Unexpose deployment** — Remove external access
- **Add custom domain** — Connect your own domain (e.g., `app.example.com`)
- **Verify custom domain** — Check DNS configuration
- **Remove custom domain** — Disconnect a custom domain

### Step 3: Execute action

#### Expose deployment

Resolve the deployment ID, then call:

```bash
response=$(wf_post "/api/deploy/${DEPLOYMENT_ID}/expose")
DOMAIN=$(wf_json_field "$response" "data.hostname")
```

Output: `Deployment exposed at: https://{domain}`

#### Unexpose deployment

```bash
response=$(wf_post "/api/deploy/${DEPLOYMENT_ID}/unexpose")
```

#### Add custom domain

Use AskUserQuestion to collect the deployment name and custom domain hostname.

```bash
body=$(jq -n --arg id "$DEPLOYMENT_ID" --arg host "$CUSTOM_DOMAIN" \
  '{deploymentId: $id, hostname: $host}')
response=$(wf_post "/api/domains" "$body")
```

Show DNS instructions:

```
Add a CNAME record to your DNS provider:

  Type:   CNAME
  Name:   {subdomain}
  Value:  custom.willform.ai

After adding the record, run: /wf-domain verify {custom_domain}
```

#### Verify custom domain

```bash
response=$(wf_post "/api/domains/${DOMAIN_ID}/verify")
```

#### Remove custom domain

```bash
response=$(wf_delete "/api/domains/${DOMAIN_ID}")
```

### Step 4: Report result

Show the result with the relevant URL or status. Suggest `/wf-status` to verify the deployment.

## Error Handling

- If API returns 401, suggest `/wf-setup`
- If deployment not found, list available deployments
- If DNS verification fails, show expected CNAME and suggest waiting for propagation
