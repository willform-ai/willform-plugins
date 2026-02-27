# Willform Agent REST API Reference

Base URL: `https://agent.willform.ai`
Auth: `Authorization: Bearer wf_sk_*`
All responses: `{ success: boolean, data?: T, error?: string }`

---

## Namespaces

### POST /api/namespaces

Create a new namespace.

```
Auth: Bearer wf_sk_*
Body: {
  "name": "string (required)",
  "allocatedCores": "number (required, 1-32)",
  "allocatedMemoryGb": "number (required, 1-128)"
}
Response: {
  "success": true,
  "data": {
    "id": "uuid",
    "shortId": "string",
    "k8sNamespace": "string",
    "allocatedMemoryGb": 8
  }
}
```

Note: create response is minimal. Use `GET /api/namespaces/{id}` for full details.
Returns 409 if a namespace with the same name already exists for this user.
Returns 402 `INSUFFICIENT_RUNWAY` if balance / total burn rate < 2 hours.

### GET /api/namespaces

List all namespaces for the authenticated user.

```
Auth: Bearer wf_sk_*
Response: {
  "success": true,
  "data": [
    { "id": "uuid", "shortId": "string", "name": "string", "status": "active", ... }
  ]
}
```

### GET /api/namespaces/{id}

Get namespace detail including deployments.

```
Auth: Bearer wf_sk_*
Response: {
  "success": true,
  "data": {
    "id": "uuid",
    "shortId": "string",
    "name": "string",
    "status": "active",
    "cpuCores": 4,
    "memoryGb": 8,
    "deployments": [ ... ],
    "createdAt": "ISO8601"
  }
}
```

### PUT /api/namespaces/{id}

Update namespace settings.

```
Auth: Bearer wf_sk_*
Body: {
  "name?": "string",
  "allocatedCores?": "number (1-32)",
  "allocatedMemoryGb?": "number (1-128)"
}
Response: {
  "success": true,
  "data": { "id": "uuid", "name": "string", "allocatedCores": 4, "allocatedMemoryGb": 8 }
}
```

Returns 402 `INSUFFICIENT_RUNWAY` if increasing resources and balance / total burn rate < 2 hours.

### DELETE /api/namespaces/{id}

Delete a namespace. Cascades to all deployments and domains.

```
Auth: Bearer wf_sk_*
Response: { "success": true }
```

### POST /api/namespaces/{id}/suspend

Suspend a namespace. All deployments become `"suspended"`.

```
Auth: Bearer wf_sk_*
Response: { "success": true }
```

### POST /api/namespaces/{id}/resume

Resume a suspended namespace.

```
Auth: Bearer wf_sk_*
Response: { "success": true }
```

Returns 402 `INSUFFICIENT_RUNWAY` if balance / total burn rate < 2 hours.

---

## Deployments

### POST /api/deploy

Create a new deployment.

```
Auth: Bearer wf_sk_*
Body: {
  "namespaceId": "uuid (required)",
  "name": "string (required)",
  "image": "string (required)",
  "chartType?": "web | database | queue | cache | storage | worker | cronjob | job | static-site",
  "port?": "number",
  "env?": "{ KEY: VALUE }",
  "replicas?": "number",
  "volumeSizeGb?": "number (0-100, default: 0)",
  "volumeMountPath?": "string (default: /data)",
  "healthCheckPath?": "string | null (null disables health check)",
  "fsGroup?": "number",
  "registryAuth?": "{ server: string, username: string, password: string } | null",
  "schedule?": "string (cron expression, required for cronjob)",
  "concurrencyPolicy?": "Forbid | Allow | Replace (for cronjob)",
  "command?": "string[] (override ENTRYPOINT — replaces entrypoint script entirely)",
  "args?": "string[] (override CMD — keeps entrypoint intact, use for CLI flags like --bind lan)"
}
Response: {
  "success": true,
  "data": {
    "deploymentId": "uuid",
    "namespaceId": "uuid",
    "shortId": "string",
    "internalEndpoint": "string",
    "chartType": "string",
    "status": "string"
  }
}
```

Note: response uses `deploymentId` (not `id`). No `domain` field — domain is a separate action.
Returns 402 `INSUFFICIENT_RUNWAY` if deployment has storage (volumeSizeGb > 0) and balance / total burn rate < 2 hours.

### GET /api/deploy

List all deployments for the authenticated user.

```
Auth: Bearer wf_sk_*
Response: {
  "success": true,
  "data": [
    { "id": "uuid", "name": "string", "status": "string", "chartType": "string", ... }
  ]
}
```

### GET /api/deploy/{id}

Get deployment status.

```
Auth: Bearer wf_sk_*
Response: {
  "success": true,
  "data": {
    "id": "uuid",
    "name": "string",
    "status": "running | pending | stopped | suspended | failed",
    "chartType": "string",
    "image": "string",
    "port": "number",
    "replicas": "number",
    "domain": "string | null",
    "createdAt": "ISO8601"
  }
}
```

Note: status response uses `id` (not `deploymentId`).

### DELETE /api/deploy/{id}

Delete a deployment and all associated K8s resources.

```
Auth: Bearer wf_sk_*
Response: { "success": true }
```

### PUT /api/deploy/{id}/stop

Stop a running deployment (sets replicas to 0 or suspends cronjob).

```
Auth: Bearer wf_sk_*
Response: { "success": true }
```

### PUT /api/deploy/{id}/restart

Restart a stopped deployment. The deployment must be in `"stopped"` status first.

```
Auth: Bearer wf_sk_*
Response: { "success": true }
```

### POST /api/deploy/{id}/expose

Expose a deployment with its default domain (`{name}-{shortId}.willform.ai`).

```
Auth: Bearer wf_sk_*
Response: {
  "success": true,
  "data": {
    "hostname": "string",
    "deploymentId": "uuid"
  }
}
```

### GET /api/deploy/{id}/logs

Get recent logs from deployment pods.

```
Auth: Bearer wf_sk_*
Response: {
  "success": true,
  "data": {
    "logs": "string"
  }
}
```

---

## Credits & Billing

### GET /api/credits/balance

Get current credit balance.

```
Auth: Bearer wf_sk_*
Response: {
  "success": true,
  "data": {
    "balance": "string (numeric, e.g. '42.50000000')",
    "currency": "USD",
    "rates": {
      "computePerSecond": "string",
      "memoryPerSecond": "string",
      "storagePerSecond": "string"
    }
  }
}
```

The `rates` field shows current per-second burn rates across all running deployments.

### GET /api/credits/transactions

Get transaction history with usage windows and rates.

```
Auth: Bearer wf_sk_*
Response: {
  "success": true,
  "data": {
    "deposits": [ { "amount": "string", "type": "string", "createdAt": "ISO8601" } ],
    "windows": [ ... ],
    "rates": { "compute": "string", "memory": "string", "storage": "string" }
  }
}
```

### POST /api/credits/deposit

Record a crypto deposit.

```
Auth: Bearer wf_sk_*
Body: {
  "txHash": "string (0x-prefixed, 66 chars)",
  "chainId": "number",
  "tokenSymbol": "USDC | USDT"
}
Response: {
  "success": true,
  "data": { "amount": "string", "transactionId": "uuid" }
}
```

### POST /api/credits/topup

Card-based top-up via Paddle.

```
Auth: Bearer wf_sk_*
Body: { "amount": "number" }
Response: {
  "success": true,
  "data": { "checkoutUrl": "string" }
}
```

---

## Domains

### GET /api/domains

List all domains for the authenticated user.

```
Auth: Bearer wf_sk_*
Response: {
  "success": true,
  "data": [
    { "id": "uuid", "hostname": "string", "deploymentId": "uuid", "type": "default | custom", "status": "string" }
  ]
}
```

### POST /api/domains

Create a custom domain for a deployment.

```
Auth: Bearer wf_sk_*
Body: {
  "deploymentId": "uuid",
  "hostname": "string (e.g. app.example.com)"
}
Response: {
  "success": true,
  "data": {
    "id": "uuid",
    "hostname": "string",
    "cfCustomHostnameId": "string",
    "dnsInstructions": [
      { "type": "CNAME", "name": "app.example.com", "value": "custom.willform.ai" }
    ]
  }
}
```

### DELETE /api/domains/{id}

Delete a domain. Cannot delete a default domain that has a linked custom domain (409).

```
Auth: Bearer wf_sk_*
Response: { "success": true }
```

### POST /api/domains/{id}/verify

Verify DNS for a custom domain.

```
Auth: Bearer wf_sk_*
Response: {
  "success": true,
  "data": { "status": "active | pending | failed" }
}
```

---

## API Keys

### GET /api/keys

List all API keys for the authenticated user.

```
Auth: Bearer wf_sk_*
Response: {
  "success": true,
  "data": [
    { "id": "uuid", "name": "string", "prefix": "wf_sk_xxxx", "createdAt": "ISO8601" }
  ]
}
```

### POST /api/keys

Create a new API key.

```
Auth: Bearer wf_sk_*
Body: { "name": "string" }
Response: {
  "success": true,
  "data": {
    "id": "uuid",
    "name": "string",
    "key": "wf_sk_... (shown only once)"
  }
}
```

### DELETE /api/keys/{id}

Delete an API key.

```
Auth: Bearer wf_sk_*
Response: { "success": true }
```

---

## Health

### GET /api/health

Health check endpoint. No auth required.

```
Response: { "status": "ok" }
```
