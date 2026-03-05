---
name: wf-agent
description: Interact with Willy AI agents on Willform Agent
allowed-tools: Bash, Read, AskUserQuestion
user-invocable: true
---

# /wf-agent -- Willy Agent Interaction

## Goal

Check Willy agent status, send prompts, invoke tools, and recover crashed agents on Willform Agent.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

### Step 1: Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### Step 2: Resolve namespace

Agent operations require a `namespaceId`. List namespaces and resolve:

```bash
ns_response=$(wf_get "/api/namespaces")
```

- If only one namespace exists, use it automatically
- If multiple exist, ask the user to select one via AskUserQuestion
- If none exist, tell the user to create one first (`/wf-namespace`)

Extract the `id` field from the selected namespace.

### Step 3: Determine action

If an argument is provided (`$ARGUMENTS`):
- `status` or no argument → show agent status
- `chat <prompt>` → send a prompt to the agent
- `recover` → attempt to recover a crashed agent

Otherwise, use AskUserQuestion:
- **Agent status** — Check if Willy agent is running and healthy
- **Chat with agent** — Send a prompt to Willy
- **Recover agent** — Restart a crashed or unresponsive agent

### Step 4: Execute action

All agent operations use `wf_mcp` (MCP JSON-RPC via `/api/mcp`, no REST equivalent):

#### Agent status

```bash
response=$(wf_mcp "agent_status" "{\"namespaceId\":\"${NAMESPACE_ID}\"}")
```

The response is a JSON string. Parse and display: `status`, `systemNamespace`, `cpuCores`, `memoryGb`, `lastHealthCheck`, `errorMessage`.

#### Chat with agent

Ask for the prompt (or use remaining arguments):

```bash
ESCAPED_MSG=$(echo "$PROMPT" | jq -Rs '.')
response=$(wf_mcp "agent_chat" "{\"namespaceId\":\"${NAMESPACE_ID}\",\"message\":${ESCAPED_MSG}}")
```

Display the agent's response text.

**Note**: Chat requires the agent to be in `running` state. If the API returns an error about agent not running, suggest recovery or checking status first.

#### Recover agent

```bash
response=$(wf_mcp "agent_recover" "{\"namespaceId\":\"${NAMESPACE_ID}\"}")
```

Recovery only works when agent status is `failed`, `interrupted`, or `degraded`. There is a 5-minute cooldown between recovery attempts.

After triggering recovery, poll agent status (max 60s) until it reaches `running`.

### Step 5: Report result

Show the action result. For chat, display the agent's response. For status/recover, show current state.

**Agent Status Reference:**

| Status | Meaning |
|--------|---------|
| running | Agent is healthy and accepting requests |
| starting | Agent is booting up |
| failed | Agent crashed, needs recovery |
| interrupted | Agent was interrupted, needs recovery |
| degraded | Agent partially functional, recovery recommended |
| not_provisioned | No agent exists for this namespace |

## Error Handling

- If API returns 401, suggest `/wf-setup`
- If MCP response contains `error`, display the error message
- If agent status is `not_provisioned`, note that the Willy agent has not been created for this namespace yet
- If recovery returns 409 (cooldown), tell the user to wait and try again later
- If chat returns 409 (not running), suggest checking status or recovering first
