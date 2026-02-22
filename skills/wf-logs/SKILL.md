---
name: wf-logs
description: View deployment logs from Willform Agent
allowed-tools: Bash, Read
user-invocable: true
---

# View Deployment Logs

Retrieve and display container logs for a deployment on Willform Agent.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. See `skills/willform-deploy/references/language-guidelines.md` for output conventions. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

A deployment ID or name must be provided as an argument (`$ARGUMENTS`). If no argument is provided, show an error and list available deployments.

1. Source the API helper and load config:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

2. **Resolve deployment ID**:
   - If the argument looks like a UUID, use it directly as the deployment ID
   - Otherwise, treat it as a deployment name: call `GET /api/deploy` to list all deployments, then find the one matching the given name
   - If no match is found, show an error with the list of available deployments:
     ```
     Error: Deployment "xyz" not found.

     Available deployments:
       NAME            STATUS      ID
       my-web          running     abc-123-...
       my-db           running     def-456-...
     ```

3. **Fetch logs** using the shared helper:

```bash
response=$(wf_get "/api/deploy/${DEPLOY_ID}/logs")
```

4. **Output the logs**:
   - Extract the log text from the `data` field in the response
   - Output the raw log text directly so the user can read it
   - If the response indicates an error (e.g., deployment not found, no logs available), show the error message clearly

5. **Error handling**:
   - If the API returns `success: false`, display the error message
   - If the deployment status is `stopped` or `suspended`, note that logs may not be available since no pods are running
