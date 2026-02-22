---
name: wf-status
description: Check deployment status on Willform Agent
allowed-tools: Bash, Read
user-invocable: true
---

# Check Deployment Status

Check the status of deployments on Willform Agent.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. See `skills/willform-deploy/references/language-guidelines.md` for output conventions. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

1. Source the API helper and load config:

```bash
source scripts/wf-api.sh && wf_load_config
```

2. If a specific deployment name or ID is provided as an argument (`$ARGUMENTS`), show detailed status for that deployment. Otherwise, list all deployments.

### List All Deployments

Call `GET /api/deploy` using the shared helper:

```bash
response=$(wf_get "/api/deploy")
```

Parse the JSON response (`data` is an array of deployments). For each deployment, extract: `name`, `status`, `chartType`, `domain` (may be null), `namespaceId`.

Format output:

```
Deployments:
  NAME            STATUS      TYPE        DOMAIN
  my-web          running     web         my-web-a1b2c3d4.willform.ai
  my-db           running     database    —
  test-worker     stopped     worker      —
```

Use `—` when domain is null/empty.

### Detailed Status (specific deployment)

If an argument is provided, first try to use it as a deployment ID directly. If that fails (non-UUID format), resolve the name to an ID by searching the deployment list.

Then fetch:

1. **Deployment details**: `GET /api/deploy/{id}`
   - Show: name, status, chartType, image, domain, createdAt, resources
2. **Namespace info**: `GET /api/namespaces/{namespaceId}` (use namespaceId from deployment response)
   - Show: namespace name, status, quota usage
3. **Credit balance**: `GET /api/credits/balance`
   - Show: current balance

Format as a readable summary:

```
Deployment: my-web
  Status:     running
  Type:       web
  Image:      nginx:latest
  Domain:     my-web-a1b2c3d4.willform.ai
  Created:    2026-02-20T10:30:00Z

Namespace: a1b2c3d4-user
  Status:     active

Credits:
  Balance:    $42.50
```

If the deployment is not found, show an error message along with the list of available deployments.
