# OpenClaw Deployment Specification

OpenClaw is an open-source AI agent runtime. This document describes the deployment configuration for running OpenClaw on Willform Agent.

## Image

```
ghcr.io/openclaw/openclaw:latest
```

## Architecture

OpenClaw's Control UI has a WebSocket auth bug when using `bind: lan` (Issues #7749, #1679, #4941). Use `bind: loopback` with an HTTP reverse proxy:

- Gateway binds to `127.0.0.1:18790` (loopback)
- Node.js HTTP reverse proxy: `0.0.0.0:18789` → `127.0.0.1:18790`
- Volume mount: `/home/node/.openclaw` (OpenClaw's default config dir)
- The HTTP proxy strips Cloudflare proxy headers (X-Forwarded-For, CF-Connecting-IP, etc.) but preserves the original Host and Origin headers (do NOT rewrite them — rewriting breaks cookie domain for device identity). Socket remoteAddress is 127.0.0.1. Use `allowedOrigins` in openclaw.json to whitelist the external domain.

## Network

- External port: 18789 (TCP proxy)
- Internal port: 18790 (gateway loopback)
- Health check: none (`healthCheckPath: "null"`)
- Chart type: web

## Required Environment Variables

One LLM API key is required:

| Variable            | Provider    | Example                       |
|---------------------|-------------|-------------------------------|
| `OPENROUTER_API_KEY`| OpenRouter  | `sk-or-v1-...`                |
| `OPENAI_API_KEY`    | OpenAI      | `sk-...`                      |
| `ANTHROPIC_API_KEY` | Anthropic   | `sk-ant-...`                  |
| `GOOGLE_API_KEY`    | Google Gemini | `AIza...`                   |

Plus:

| Variable                  | Description              | Example              |
|---------------------------|--------------------------|----------------------|
| `OPENCLAW_GATEWAY_TOKEN`  | Control UI auth token    | `openssl rand -hex 16` |

## Optional Environment Variables

| Variable              | Description                        | Default |
|-----------------------|------------------------------------|---------|
| `TELEGRAM_BOT_TOKEN`  | Telegram bot token from @BotFather | —       |

## Config Files (written via startup command)

| File | Purpose |
|------|---------|
| `/home/node/.openclaw/openclaw.json` | Gateway config (bind, port, auth, channels, tools) |
| `/home/node/.openclaw/soul.md` | Agent personality / system prompt |
| `/home/node/.openclaw/agents.md` | Agent behavior rules |

## Resources

- CPU: 2 cores
- Memory: 4 GB

## Startup Command

The container runs `sh -c "..."` that:

1. Writes `openclaw.json` via heredoc
2. Writes `soul.md` via heredoc
3. Writes `agents.md` via heredoc
4. Starts HTTP reverse proxy in background (strips Cloudflare headers for auto-pairing)
5. Execs `node dist/index.js gateway --allow-unconfigured`

HTTP reverse proxy (Node.js, strips proxy headers + handles WebSocket upgrade):
```javascript
const h=require('http'),n=require('net'),
S=['x-forwarded-for','x-forwarded-proto','x-real-ip',
   'cf-connecting-ip','cf-ray','cf-visitor','cf-ipcountry',
   'cdn-loop','cf-worker'];
const s=h.createServer((q,r)=>{
  S.forEach(k=>delete q.headers[k]);
  const p=h.request({hostname:'127.0.0.1',port:18790,
    path:q.url,method:q.method,headers:q.headers},
    x=>{r.writeHead(x.statusCode,x.headers);x.pipe(r)});
  q.pipe(p);p.on('error',()=>r.destroy())
});
s.on('upgrade',(q,sk,hd)=>{
  S.forEach(k=>delete q.headers[k]);
  const p=n.connect(18790,'127.0.0.1',()=>{
    let r=q.method+' '+q.url+' HTTP/1.1\r\n';
    for(const[k,v]of Object.entries(q.headers))
      r+=k+': '+v+'\r\n';
    r+='\r\n';p.write(r);
    if(hd.length)p.write(hd);
    sk.pipe(p);p.pipe(sk)
  });
  p.on('error',()=>sk.destroy());
  sk.on('error',()=>p.destroy())
});
s.listen(18789,'0.0.0.0')
```

## Deploy Body Example

```json
{
  "namespaceId": "<namespace-id>",
  "name": "openclaw",
  "image": "ghcr.io/openclaw/openclaw:latest",
  "port": 18789,
  "chartType": "web",
  "replicas": 1,
  "volumeSizeGb": 10,
  "volumeMountPath": "/home/node/.openclaw",
  "healthCheckPath": "null",
  "env": {
    "ANTHROPIC_API_KEY": "<your-key>",
    "OPENCLAW_GATEWAY_TOKEN": "<random-token>",
    "TELEGRAM_BOT_TOKEN": "<optional>"
  },
  "command": ["sh", "-c", "<startup-command>"]
}
```

## First Access

Open `https://{domain}/?token={OPENCLAW_GATEWAY_TOKEN}` in a browser to pair your device. After pairing, the token is no longer needed in the URL.

## Known Issues

- **"pairing required" / "device identity required" (code 1008) behind Cloudflare Tunnel**: Two separate mechanisms interact:
  1. **Proxy headers**: OpenClaw detects remote client from Cloudflare headers → requires pairing. Fix: HTTP reverse proxy that strips proxy headers.
  2. **Cookie domain**: If the proxy rewrites Host to `127.0.0.1:18790`, OpenClaw sets cookies for localhost domain, but the browser is on the external domain → cookies rejected → device identity never persists. Fix: do NOT rewrite Host/Origin headers.
  3. **Origin check**: With external Host, OpenClaw logs "non-local Host, treating as remote" and requires explicit `allowedOrigins`. Fix: add `"allowedOrigins": ["https://your-domain.willform.ai"]` to `controlUi`.
  4. **Device pairing**: `dangerouslyDisableDeviceAuth: true` skips the pairing approval step but does NOT skip device identity registration. User must still visit `/?token=TOKEN` once.
  Combined fix: strip Cloudflare headers + preserve Host/Origin + set `allowedOrigins` + `dangerouslyDisableDeviceAuth: true`.
- **`bind: lan` + token_missing**: Control UI WebSocket doesn't pass the gateway token in the handshake (Issues #7749, #1679, #4941). Use `loopback` + HTTP reverse proxy instead.
- **`auth.mode: "none"` invalid**: OpenClaw only supports `"token"` and `"pairing"` auth modes.
- **`trustedProxies` gotcha**: Adding `127.0.0.0/8` to trustedProxies makes OpenClaw trust the proxy and resolve the real client IP from X-Forwarded-For → remote IP → still requires pairing. The correct fix is to strip the headers, not add loopback to trustedProxies.
- **`allowedOrigins` does NOT support wildcards**: `"*"` is not valid. Must use exact origin URLs like `"https://example.willform.ai"`. Use `OPENCLAW_DOMAIN` env var + unquoted heredoc for dynamic expansion.
- **"non-local Host header, treating as remote"**: Logged when socket is localhost but Host is external domain. This warning means OpenClaw will enforce `allowedOrigins` — it is NOT harmless if `allowedOrigins` is not configured.
