# Status Interpretation Guide

## Deployment Statuses

| Status | Meaning | Action |
|--------|---------|--------|
| pending | Pods starting up, pulling images, running init containers | Wait, check again in 30s |
| running | All pods healthy and serving traffic | No action needed |
| stopped | Manually stopped (replicas=0 or suspend=true) | Use restart/resume to bring back |
| suspended | Billing watchdog triggered (balance <= $0.01) | Top up credits |
| failed | Deployment error during creation or runtime | Check logs, run diagnosis |

## Common K8s Events

| Event | Cause | Fix |
|-------|-------|-----|
| ImagePullBackOff | Image not found, tag missing, or registry auth failed | Verify image name and tag. Check imagePullSecretName for private registries |
| CrashLoopBackOff | Application crashes repeatedly on startup | Check logs for stack traces, missing env vars, or config errors |
| OOMKilled | Container exceeded memory limit | Increase memory allocation (update namespace quota or scale deployment) |
| Pending (stuck > 60s) | Insufficient cluster resources or scheduling constraints | Scale down other deployments or request quota increase |
| ErrImagePull | Registry unreachable or image does not exist | Verify registry URL and image path. Check network connectivity |

## Namespace Statuses

| Status | Meaning |
|--------|---------|
| active | Normal operation, all deployments can run |
| suspended | All deployments paused, PVCs purged when balance <= $0.01 |
| deleted | Namespace removed permanently |

## Log Analysis Tips

- **Startup errors**: Look at the first 20 lines for initialization failures
- **Port binding**: Look for `EADDRINUSE` or `bind: address already in use` — port conflict with another process or misconfigured port
- **Missing env vars**: Look for `undefined`, `not set`, or `missing required` messages early in the logs
- **Database connections**: Look for `ECONNREFUSED`, `connection timeout`, or authentication failures — verify the database deployment is running and the connection string is correct
- **Memory issues**: Look for `JavaScript heap out of memory` or `Killed` signals — indicates OOMKilled
- **Permission errors**: Look for `EACCES` or `permission denied` — may need fsGroup configuration or root-compatible security context
