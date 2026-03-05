---
name: wf-diagnose
description: Diagnose deployment issues on Willform Agent
allowed-tools: Bash, Read
user-invocable: true
---

# /wf-diagnose -- Diagnose Deployment Issues

## Goal

Run diagnostics on a deployment to identify and troubleshoot issues. Combines deploy_diagnose, logs, and events into a single actionable report.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

A deployment name or ID must be provided as an argument (`$ARGUMENTS`). If none provided, show an error and list available deployments.

### Step 1: Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### Step 2: Resolve deployment

If the argument is a UUID, use it directly. Otherwise, call `GET /api/deploy` to find the matching deployment by name. If not found, show available deployments and stop.

### Step 3: Run diagnostics

Fetch diagnostic information:

```bash
DIAG=$(wf_get "/api/deploy/${DEPLOY_ID}/diagnose")
```

Parse the response for:
- Pod status and restart counts
- Container state (running, waiting, terminated)
- Recent events (warnings, errors)
- Resource usage vs limits

### Step 4: Fetch recent logs

```bash
LOGS=$(wf_get "/api/deploy/${DEPLOY_ID}/logs")
```

Extract the last 50 lines of logs.

### Step 5: Analyze and report

Combine diagnostics and logs into a report:

```
Diagnosis: {deployment_name}

  Status:       {status}
  Restarts:     {restart_count}
  Pod State:    {state}

Issues Found:
  - {issue 1}: {description and likely cause}
  - {issue 2}: {description and likely cause}

Recent Logs (last 20 lines):
  {log excerpt}

Recommended Actions:
  1. {action 1}
  2. {action 2}
```

**Common issue patterns:**

| Pattern | Likely Cause | Fix |
|---------|-------------|-----|
| ImagePullBackOff | Wrong image name or missing registry auth | Check image reference, add registryAuth |
| CrashLoopBackOff | App crashes on startup | Check logs for errors, missing env vars |
| OOMKilled | Memory limit exceeded | Increase namespace memory allocation |
| Pending > 60s | Scheduling issues | Check namespace quota, cluster capacity |
| Connection refused | Wrong port configuration | Verify port matches app listen port |

## Error Handling

- If API returns 401, suggest `/wf-setup`
- If deployment not found, show available deployments
- If deployment is stopped/suspended, note that diagnostics may be limited
