---
name: wf-cost
description: Check credit balance and estimate costs on Willform Agent
allowed-tools: Bash, Read
user-invocable: true
---

# /wf-cost — Credit Balance & Cost Estimator

Check the current credit balance and estimate burn rate for all running deployments on Willform Agent.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. See `skills/willform-deploy/references/language-guidelines.md` for output conventions. If not set, ask the user to choose (English/한국어) and save to config.

## Steps

1. Source the API helper and load config:
   ```bash
   source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
   ```

2. Fetch the current credit balance:
   ```
   GET /api/credits/balance
   ```
   Extract `data.balance` (string, USD).

3. Fetch all deployments:
   ```
   GET /api/deploy
   ```
   Filter to only `status: "running"` deployments.

4. For each running deployment, estimate hourly cost using default resource allocations per chart type:

   | Chart Type | Cores | Memory (GB) | Hourly Cost |
   |------------|-------|-------------|-------------|
   | web | 0.1 | 0.125 | $0.004625 |
   | database | 0.25 | 0.5 | $0.0125 |
   | queue | 0.25 | 0.5 | $0.0125 |
   | cache | 0.1 | 0.25 | $0.00525 |
   | storage | 0.25 | 0.5 | $0.0125 |
   | worker | 0.1 | 0.25 | $0.00525 |
   | cronjob | 0.1 | 0.125 | $0.004625 |
   | static-site | 0.05 | 0.0625 | $0.002313 |

   Formulas:
   - Compute cost = cores * $0.04
   - Memory cost = memory_gb * $0.005
   - Hourly cost = compute + memory (storage not included in default estimates)

5. Calculate totals:
   - Total hourly burn rate = sum of all running deployment hourly costs
   - Daily projected = hourly * 24
   - Monthly projected = hourly * 730
   - Remaining time = balance / hourly_rate (in days)

6. Format and display output:

   ```
   Credit Balance: $15.42

   Running Deployments:
     NAME          TYPE      HOURLY COST
     my-web        web       $0.0046
     my-db         database  $0.0135
     Total                   $0.0181

   Projections:
     Daily:     $0.43
     Monthly:   $13.22
     Remaining: ~35 days

   Status: OK
   ```

7. If balance <= $1.00 OR remaining time < 24 hours, append a warning:

   ```
   WARNING: LOW BALANCE — top up soon to avoid suspension and PVC purge!
   ```

## Notes

- Storage costs are not included in default estimates since storage allocation varies per deployment. Actual burn rate may be higher if deployments use persistent volumes.
- Cronjob costs only apply while the job is actively running, not while suspended between runs.
- The `GET /api/deploy` endpoint returns deployments across all namespaces for the authenticated user.
- All monetary values from the API are strings (numeric(18,8)). Parse carefully — do not use floating point for comparisons near the $0.01 threshold.
