---
name: cost-tracking
description: Track credit balance, estimate deployment costs, and manage billing on Willform Agent
---

# Cost Tracking & Billing

Track credit balance, estimate deployment costs, and manage billing on Willform Agent.

## Overview

Willform Agent uses per-second billing for all running workloads. Credits are deducted continuously while deployments are active. A watchdog process checks balances every 5 minutes and suspends namespaces when funds are depleted.

All monetary values are stored as `numeric(18,8)` strings — never use JavaScript floats for money calculations.

## Key Endpoints

All endpoints require authentication via `wf_sk_*` API key in the `Authorization: Bearer` header. Responses are wrapped in `{ success: boolean, data?: T, error?: string }`.

### GET /api/credits/balance

Returns current credit balance.

```json
{
  "success": true,
  "data": {
    "balance": "15.42000000",
    "currency": "USD"
  }
}
```

### GET /api/credits/transactions

Returns transaction history grouped by type.

```json
{
  "success": true,
  "data": {
    "deposits": [...],
    "windows": [...],
    "rates": {...}
  }
}
```

Note: This returns a structured object with `deposits`, `windows`, and `rates` — NOT a flat array.

### POST /api/credits/deposit

Record a crypto deposit.

```json
{
  "txHash": "0x...",
  "chainId": 8453,
  "tokenSymbol": "USDC"
}
```

### POST /api/credits/topup

Card payment topup via Paddle. Minimum topup: $2.00.

## Billing Model

### Per-Second Billing

Running workloads are billed every second for three resource dimensions:

| Resource | Rate |
|----------|------|
| Compute | $0.04 per core per hour |
| Memory | $0.005 per GB per hour |
| Storage | $0.0001 per GB per hour |

### Watchdog

- Checks balance every 5 minutes
- Suspends namespace when balance <= $0.01
- **All PVCs (databases, volumes) are purged on suspension!**

## Cost Estimation Formulas

```
Hourly cost  = (cores * $0.04) + (memory_gb * $0.005) + (storage_gb * $0.0001)
Daily cost   = hourly * 24
Monthly cost = hourly * 730
Remaining hours = balance / hourly_cost
```

Example: A deployment with 0.25 cores, 512Mi memory, and 10GB storage:
- Compute: 0.25 * $0.04 = $0.01/hr
- Memory: 0.5 * $0.005 = $0.0025/hr
- Storage: 10 * $0.0001 = $0.001/hr
- Total: $0.0135/hr = $0.324/day = $9.86/month

## Payment Methods

### Card

Via Paddle integration using the topup endpoint. Minimum: $2.00.

### Crypto

USDC and USDT accepted on 6 chains:
- Ethereum (6 decimals)
- Base (6 decimals)
- Arbitrum (6 decimals)
- Optimism (6 decimals)
- Polygon (6 decimals)
- BSC (18 decimals)

## Transaction Types

| Type | Description |
|------|-------------|
| `topup` | Card payment via Paddle |
| `deposit` | Crypto deposit |
| `signup_credit` | Phone auth signup bonus |
| `x402_topup` | x402 protocol payment |
| `compute_deduct` | Per-second compute charge |
| `memory_deduct` | Per-second memory charge |
| `storage_deduct` | Per-second storage charge |

## Usage

Use the `source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config` pattern to set up authentication before making API calls.

## Warning

PVCs (databases, persistent volumes) are permanently purged when a namespace is suspended due to insufficient balance. There is no recovery. Always monitor your balance and top up before depletion.
