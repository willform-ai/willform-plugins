---
name: wf-monitor
description: Monitor deployment health and diagnose issues on Willform Agent
allowed-tools: Bash, Read
user-invocable: true
---

# /wf-monitor -- Deployment Health Monitor

## Goal

Check deployment health, diagnose common issues, and provide actionable troubleshooting for deployments on Willform Agent.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. If not set, ask the user to choose (English/한국어) and save to config.

## Steps

### 1. Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### 2. Get deployment list

If an argument is provided (`$ARGUMENTS`), resolve it to a deployment ID. Otherwise, list all deployments and show a health summary.

```bash
response=$(wf_get "/api/deploy")
```

### 3. Health check for each deployment

For each running deployment (or the specified one), check:

1. **Status**: `GET /api/deploy/{id}` — running/failed/stopped/suspended/pending
2. **Credit balance**: `GET /api/credits/balance` — warn if low

### 4. Display health summary

```
Deployment Health:
  NAME          STATUS      HEALTH    ISSUE
  my-web        running     OK        —
  my-db         running     OK        —
  test-worker   failed      ERROR     CrashLoopBackOff
```

Health values: `OK`, `WARNING`, `ERROR`

### 5. Detailed diagnosis (if specific deployment or issues found)

For deployments with issues, show:

- Current status and how long it's been in that state
- Relevant log excerpt (last 20 lines)
- Likely cause based on status pattern
- Recommended fix

### 6. Report result

**Deployment Status Reference:**

| Status | Meaning | Action |
|--------|---------|--------|
| pending | Pods starting up | Wait 30s, check again |
| running | All pods healthy | No action needed |
| stopped | Manually stopped | Use restart to bring back |
| suspended | Balance depleted | Top up credits |
| failed | Error during creation/runtime | Check logs |

**Common Issues:**

| Issue | Cause | Fix |
|-------|-------|-----|
| ImagePullBackOff | Image not found or registry auth failed | Verify image name/tag and registry credentials |
| CrashLoopBackOff | App crashes on startup | Check logs for stack traces, missing env vars |
| OOMKilled | Memory limit exceeded | Increase memory allocation |
| Pending > 60s | Image pull issue or scheduling | Verify image exists and cluster has capacity |

Suggest `/wf-logs <name>` for detailed logs or `/wf-diagnose <name>` for deeper diagnosis.

## Error Handling

- If API returns 401, suggest `/wf-setup` to reconfigure API key
- If no deployments found, suggest `/wf-deploy` to create one
- If balance is low (< $1), append a warning about potential suspension
