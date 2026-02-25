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
- The HTTP proxy strips Cloudflare proxy headers (X-Forwarded-For, CF-Connecting-IP, etc.) but preserves the Host header so Origin matches Host (passes origin check). Socket remoteAddress is 127.0.0.1 (auto-pairing).

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

- **"pairing required" (code 1008) behind Cloudflare Tunnel**: OpenClaw auto-approves device pairing ONLY for connections from localhost with NO proxy headers. A raw TCP proxy relays Cloudflare headers (X-Forwarded-For, CF-Connecting-IP, etc.) → OpenClaw detects remote client → requires admin approval → chicken-and-egg deadlock on first device. Fix: use HTTP reverse proxy that strips proxy headers (see Startup Command above). Ref: OpenClaw Discussion #12437, Issue #1679.
- **`bind: lan` + token_missing**: Control UI WebSocket doesn't pass the gateway token in the handshake (Issues #7749, #1679, #4941). Use `loopback` + HTTP reverse proxy instead.
- **`auth.mode: "none"` invalid**: OpenClaw only supports `"token"` and `"pairing"` auth modes.
- **`trustedProxies` gotcha**: Adding `127.0.0.0/8` to trustedProxies makes OpenClaw trust the proxy and resolve the real client IP from X-Forwarded-For → remote IP → still requires pairing. The correct fix is to strip the headers, not add loopback to trustedProxies.
- **"origin not allowed" (code 1008) behind reverse proxy**: OpenClaw validates browser `Origin` header against the request `Host` header. If the proxy overrides `Host` to `127.0.0.1:18790`, the external-domain Origin mismatches → rejected. Fix: do NOT override `Host` header — let the original external Host pass through so Origin host matches Host. Note: `allowedOrigins` does NOT support wildcards (`"*"`); only exact origin URLs like `"https://example.com"`.
- **"non-local Host header, treating as remote"**: Logged when socket is localhost but Host is external domain. This is a warning only — does NOT prevent auto-pairing. The proxy's socket remoteAddress (127.0.0.1) is the actual locality signal for auto-pairing, not the Host header.
