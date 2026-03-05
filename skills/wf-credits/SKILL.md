---
name: wf-credits
description: Manage credits and deposits on Willform Agent
allowed-tools: Bash, Read, AskUserQuestion
user-invocable: true
---

# /wf-credits -- Credits & Deposits

## Goal

Check credit balance, view deposit options, and verify deposits on Willform Agent. Guides users through the deposit flow for topping up their account.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

### Step 1: Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### Step 2: Determine action

If an argument is provided (`$ARGUMENTS`):
- `balance` or no argument → show balance
- `deposit` → show deposit options
- `verify` → verify a pending deposit

Otherwise, use AskUserQuestion:
- **Check balance** — View current credit balance and burn rate
- **Deposit credits** — See deposit options (crypto chains, fiat)
- **Verify deposit** — Confirm a pending deposit transaction

### Step 3: Execute action

#### Check balance

```bash
response=$(wf_get "/api/credits/balance")
```

Parse and display:

```
Credit Balance:
  Available:    ${balance}
  Burn Rate:    ${burnRate}/hr
  Runway:       {hours}h remaining

Note: Minimum 2h runway required for new deployments.
```

If balance is low (< $1), show a warning about potential suspension.

#### Deposit options

```bash
response=$(wf_get "/api/credits/deposit-info")
```

Show available deposit methods:

```
Deposit Options:

  Crypto (6 chains):
    Ethereum, Base, Arbitrum, Optimism, Polygon, BSC
    Tokens: USDC, USDT
    Address: {deposit_address}

  Fiat:
    Visit https://agent.willform.ai/dashboard to pay with card
```

#### Verify deposit

Ask for the transaction hash, then verify:

```bash
body=$(jq -n --arg hash "$TX_HASH" '{txHash: $hash}')
response=$(wf_post "/api/credits/deposit-verify" "$body")
```

Show verification result (confirmed amount, new balance).

### Step 4: Report result

After any action, show current balance and suggest next steps:
- If balance is healthy: `/wf-deploy` to deploy
- If balance is low: deposit instructions

## Error Handling

- If API returns 401, suggest `/wf-setup`
- If deposit verification fails, show the error and suggest checking the transaction on a block explorer
