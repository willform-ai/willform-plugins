---
name: wf-setup
description: Configure Willform Agent API key and base URL
allowed-tools: Bash, Read, Write, AskUserQuestion
user-invocable: true
---

# /wf-setup — Willform Agent API Key Setup

## Goal
Save the user's Willform Agent API key and preferences to `~/.claude/willform-plugins.local.md` so all `/wf-*` commands can authenticate and localize automatically.

## Steps

1. Check if `~/.claude/willform-plugins.local.md` already exists. If it does, read it and show the current config (mask the API key: show first 10 chars + `***`).

2. **Language selection**: Ask the user for their preferred language using AskUserQuestion:
   - Question: "Which language do you prefer? / 어떤 언어를 사용하시겠습니까?"
   - Options: "English (Recommended)" / "한국어"
   - If already configured, offer to keep current or change

3. Ask the user for their API key using AskUserQuestion:
   - Question: "Enter your Willform Agent API key (wf_sk_...)"
   - If they already have one configured, offer to keep current or replace

4. Validate the key format: must start with `wf_sk_`

5. Ask for base URL (default: `https://agent.willform.ai`). Most users should keep the default.

6. Write the config file:

```
api_key: <their_key>
base_url: <their_url>
language: <en or ko>
```

Path: `~/.claude/willform-plugins.local.md`

7. Verify connectivity by calling the health endpoint:

```bash
curl -s -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer <api_key>" \
  "<base_url>/api/health"
```

8. Report result (in the user's selected language):

   **English**:
   - 200: "Connected successfully. Run /wf-help to see all available commands."
   - Other: "Connection failed (HTTP <code>). Check your API key and network."

   **Korean**:
   - 200: "연결 성공. /wf-help 를 실행하면 사용 가능한 모든 명령어를 확인할 수 있습니다."
   - Other: "연결 실패 (HTTP <code>). API 키와 네트워크를 확인하세요."
