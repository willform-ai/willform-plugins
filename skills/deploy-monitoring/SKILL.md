# Deploy Monitoring

Monitor deployment health, retrieve logs, and diagnose issues on Willform Agent.

## Overview

This skill helps you check the status of deployments running on Willform Agent (https://agent.willform.ai), retrieve container logs, and troubleshoot common deployment problems.

All API calls require a `wf_sk_*` API key in the Bearer header. Use `source scripts/wf-api.sh && wf_load_config` to set up authenticated API calls.

All API responses are wrapped in `{ success: boolean, data?: T, error?: string }`.

## Deployment Status Workflow

```
pending → running → stopped → suspended → failed
```

| Status | Description |
|--------|-------------|
| pending | Deployment created, waiting for pods to start and become ready |
| running | All pods are healthy and serving traffic |
| stopped | Manually stopped by user (replicas=0 or suspend=true for cronjobs) |
| suspended | Namespace suspended by billing watchdog (credit balance <= $0.01). All PVCs are purged |
| failed | Deployment encountered an error during creation or runtime |

## Key Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | /api/deploy/{id} | Full deployment status with domain info |
| GET | /api/deploy/{id}/logs | Container logs |
| GET | /api/deploy | List all deployments |
| GET | /api/namespaces/{id} | Namespace status and quota info |
| GET | /api/credits/balance | Current credit balance |

## Diagnosis Steps

1. **Check deployment status** via `GET /api/deploy/{id}`
2. **If failed**: retrieve logs via `GET /api/deploy/{id}/logs` and look for crash reasons or OOM events
3. **If suspended**: check credit balance via `GET /api/credits/balance` — balance <= $0.01 triggers suspension
4. **If pending too long** (> 60s): likely an image pull issue — verify image name and registry access

## Common Issues

### ImagePullBackOff
- **Cause**: Image name is incorrect, tag doesn't exist, or private registry lacks credentials
- **Fix**: Verify the image name and tag. If private, ensure `imagePullSecretName` is configured

### CrashLoopBackOff
- **Cause**: Application crashes on startup repeatedly
- **Fix**: Check logs for stack traces, missing env vars, or port binding failures

### Suspended
- **Cause**: Credit balance depleted (watchdog triggers at balance <= $0.01)
- **Fix**: Top up credits via deposit or Paddle payment. Namespace and deployments resume automatically after top-up

### OOMKilled
- **Cause**: Container exceeded its memory allocation
- **Fix**: Increase memory allocation by updating the namespace quota or scaling the deployment
