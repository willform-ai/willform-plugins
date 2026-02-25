---
name: wf-deploy-openclaw
description: Deploy an OpenClaw AI agent (with optional soul preset) to Willform Agent
allowed-tools: Bash, Read, Write, AskUserQuestion
user-invocable: true
---

# /wf-deploy-openclaw — Deploy OpenClaw Agent

## Goal

Deploy an OpenClaw AI agent runtime to Willform Agent with Telegram integration.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. See `skills/willform-deploy/references/language-guidelines.md`. If not set, ask the user to choose and save to config.

## Deployment Template

This is the target deployment structure. Collect user input (Steps 1-8), then build this JSON and deploy (Step 9).

### Architecture

- Image: `ghcr.io/openclaw/openclaw:latest`
- Gateway: loopback(`127.0.0.1:18790`) + HTTP reverse proxy(`0.0.0.0:18789` → `127.0.0.1:18790`, strips Cloudflare headers)
- Volume: `/home/node/.openclaw` (10GB)
- healthCheckPath: `"null"` (string)
- Why loopback: `bind: lan` fails with `token_missing` due to OpenClaw Control UI WebSocket auth bug
- Why HTTP proxy (not TCP): TCP proxy relays Cloudflare headers verbatim → OpenClaw detects remote client → requires device pairing approval with no admin to approve (chicken-and-egg). HTTP proxy strips proxy headers but preserves Host header → Origin matches Host (passes origin check) + socket is localhost (auto-pairing).

### Env Variables

- `${LLM_KEY_VAR}`: LLM API key (var name depends on provider)
- `TELEGRAM_BOT_TOKEN`: Telegram bot token (optional)
- `OPENCLAW_GATEWAY_TOKEN`: Control UI auth token

### Container Startup Command (`sh -c`)

1. Write `/home/node/.openclaw/openclaw.json`:

```json
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18790,
    "controlUi": { "enabled": true, "allowInsecureAuth": true },
    "auth": { "mode": "token" },
    "trustedProxies": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "open",
      "allowFrom": ["*"]
    }
  },
  "agents": {
    "defaults": { "sandbox": { "mode": "off" } }
  },
  "tools": {
    "web": { "search": { "enabled": true }, "fetch": { "enabled": true } },
    "sandbox": {
      "tools": {
        "allow": ["exec","process","read","write","edit","sessions_list","sessions_history","sessions_send","sessions_spawn","session_status","browser","canvas","nodes","cron","gateway","web_search","web_fetch"],
        "deny": []
      }
    }
  }
}
```

If Telegram is not configured, set `"telegram": { "enabled": false }`.

2. Write `/home/node/.openclaw/soul.md` — content from selected soul preset or user-provided text.

3. Write `/home/node/.openclaw/agents.md` — agent behavior rules from user input.

4. Start HTTP reverse proxy in background (strips Cloudflare proxy headers so OpenClaw sees clean localhost connections and auto-approves device pairing):

```javascript
node -e "const h=require('http'),n=require('net'),S=['x-forwarded-for','x-forwarded-proto','x-real-ip','cf-connecting-ip','cf-ray','cf-visitor','cf-ipcountry','cdn-loop','cf-worker'];const s=h.createServer((q,r)=>{S.forEach(k=>delete q.headers[k]);const p=h.request({hostname:'127.0.0.1',port:18790,path:q.url,method:q.method,headers:q.headers},x=>{r.writeHead(x.statusCode,x.headers);x.pipe(r)});q.pipe(p);p.on('error',()=>r.destroy())});s.on('upgrade',(q,sk,hd)=>{S.forEach(k=>delete q.headers[k]);const p=n.connect(18790,'127.0.0.1',()=>{let r=q.method+' '+q.url+' HTTP/1.1\r\n';for(const[k,v]of Object.entries(q.headers))r+=k+': '+v+'\r\n';r+='\r\n';p.write(r);if(hd.length)p.write(hd);sk.pipe(p);p.pipe(sk)});p.on('error',()=>sk.destroy());sk.on('error',()=>p.destroy())});s.listen(18789,'0.0.0.0')" &
```

5. Execute gateway:

```
exec node dist/index.js gateway --allow-unconfigured
```

### Deploy API Body

```json
{
  "namespaceId": "${NAMESPACE_ID}",
  "name": "${AGENT_NAME}",
  "image": "ghcr.io/openclaw/openclaw:latest",
  "port": 18789,
  "chartType": "web",
  "replicas": 1,
  "volumeSizeGb": 10,
  "volumeMountPath": "/home/node/.openclaw",
  "healthCheckPath": "null",
  "env": {
    "${LLM_KEY_VAR}": "${LLM_API_KEY}",
    "OPENCLAW_GATEWAY_TOKEN": "${GATEWAY_TOKEN}",
    "TELEGRAM_BOT_TOKEN": "${TELEGRAM_BOT_TOKEN}"
  },
  "command": ["sh", "-c", "${STARTUP_CMD}"]
}
```

### Deploy Sequence

1. `POST /api/namespaces` → namespace 생성 (2 cores, 4GB)
2. `POST /api/deploy` → 위 body로 배포
3. `POST /api/deploy/{id}/expose` → 도메인 노출
4. `GET /api/deploy/{id}` 폴링 → status `running` 대기

### First Access

`https://{domain}/?token={GATEWAY_TOKEN}` — 브라우저에서 열어 디바이스 페어링. 이후 토큰 불필요.

---

## Steps

### 1. Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### 2. Check language preference

If `WF_LANGUAGE` is empty, ask the user (English/한국어) and save to config.

### 3. Telegram Bot setup

Show how to create a bot via @BotFather. Use AskUserQuestion to collect:
- Bot token (validate: `[0-9]+:[A-Za-z0-9_-]+`)
- Bot username (without @)

Telegram is optional — allow skipping.

### 4. Choose LLM provider

Use AskUserQuestion:

- **OpenRouter** (Recommended) — All models with one key. https://openrouter.ai/keys
- **OpenAI** — GPT-4o, GPT-4o-mini. https://platform.openai.com/api-keys
- **Anthropic** — Claude Sonnet, Claude Haiku. https://console.anthropic.com/settings/keys
- **Google Gemini** — Gemini 2.0 Flash/Pro. https://aistudio.google.com/apikey

Provider → env var mapping:

| Provider | Env var | Prefix |
|----------|---------|--------|
| OpenRouter | `OPENROUTER_API_KEY` | `sk-or-` |
| OpenAI | `OPENAI_API_KEY` | `sk-` |
| Anthropic | `ANTHROPIC_API_KEY` | `sk-ant-` |
| Google | `GOOGLE_API_KEY` | `AIza` |

### 5. Collect API key

Show key URL for selected provider. Use AskUserQuestion to collect. Validate prefix.

### 6. Choose soul (role preset)

Read `skills/willform-deploy/references/openclaw-souls.md`. Use AskUserQuestion (Korean: "역할 프리셋"):

- **real-estate-expert** / **stock-investment-expert** / **legal-assistant** / **coding-mentor** / **data-analyst** / **writing-coach** / **custom**

If preset: load soul content and suggested model. Allow override.
If custom: ask user to provide soul content and agent behavior rules.

### 7. Gather remaining input

Use AskUserQuestion for each:

1. **Agent name** (required): Lowercase alphanumeric + hyphens.
2. **Gateway token** (required): Suggest `openssl rand -hex 16`.
3. **Agent behavior rules** (optional): For `agents.md`. Suggest defaults based on soul.
4. **Namespace**: New or existing. New namespaces need 2 cores, 4GB.

### 8. Create namespace (if needed)

```bash
RESULT=$(wf_post "/api/namespaces" "{\"name\":\"${NAMESPACE_NAME}\",\"allocatedCores\":2,\"allocatedMemoryGb\":4}")
NAMESPACE_ID=$(wf_json_field "$RESULT" "data.id")
```

### 9. Deploy

Build the startup command string from the Deployment Template above, substituting collected values. Use `jq` for safe JSON construction of the deploy body. Then:

```bash
RESULT=$(wf_post "/api/deploy" "$DEPLOY_BODY")
DEPLOYMENT_ID=$(wf_json_field "$RESULT" "data.deploymentId")

# Expose domain
RESULT=$(wf_post "/api/deploy/${DEPLOYMENT_ID}/expose")
DOMAIN=$(wf_json_field "$RESULT" "data.hostname")

# Poll for readiness (max 120s)
for i in $(seq 1 24); do
  RESULT=$(wf_get "/api/deploy/${DEPLOYMENT_ID}")
  STATUS=$(wf_json_field "$RESULT" "data.status")
  if [[ "$STATUS" == "running" ]]; then break; fi
  if [[ "$STATUS" == "failed" ]]; then
    wf_get "/api/deploy/${DEPLOYMENT_ID}/logs"
    break
  fi
  sleep 5
done
```

### 10. Report result

On success:

```
OpenClaw agent deployed successfully.

  Name:      {agent_name}
  Soul:      {soul_name}
  Provider:  {provider}
  URL:       https://{domain}
  Telegram:  https://t.me/{bot_username}  (if configured)
  Status:    running

First access:
  https://{domain}/?token={gateway_token}

Use /wf-status to check deployment health.
Use /wf-logs to view agent logs.
```

On failure/timeout: show error, suggest `/wf-logs`.
