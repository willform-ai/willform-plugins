---
allowed-tools: Bash, Read, Write, AskUserQuestion
description: Configure Willform Agent API key and base URL
user-invocable: true
---

# /wf-setup — Willform Agent API Key Setup

## Goal
Save the user's Willform Agent API key to `~/.claude/willform-plugins.local.md` so all `/wf-*` commands can authenticate automatically.

## Steps

1. Check if `~/.claude/willform-plugins.local.md` already exists. If it does, read it and show the current config (mask the API key: show first 10 chars + `***`).

2. Ask the user for their API key using AskUserQuestion:
   - Question: "Enter your Willform Agent API key (wf_sk_...)"
   - If they already have one configured, offer to keep current or replace

3. Validate the key format: must start with `wf_sk_`

4. Ask for base URL (default: `https://agent.willform.ai`). Most users should keep the default.

5. Write the config file:

```
api_key: <their_key>
base_url: <their_url>
```

Path: `~/.claude/willform-plugins.local.md`

6. Verify connectivity by calling the health endpoint:

```bash
curl -s -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer <api_key>" \
  "<base_url>/api/health"
```

7. Report result:
   - 200: "Connected successfully. You can now use /wf-status, /wf-cost, /wf-deploy-openclaw."
   - Other: "Connection failed (HTTP <code>). Check your API key and network."
