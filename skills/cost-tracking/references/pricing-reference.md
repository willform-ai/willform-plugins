# Pricing Reference

## Price Table

| Resource | Unit | Price |
|----------|------|-------|
| Compute | per core per hour | $0.04 |
| Memory | per GB per hour | $0.005 |
| Storage | per GB per hour | $0.0001 |

## Billing Mechanics

- Billing tick: every 1 second
- Watchdog check: every 5 minutes
- Suspension threshold: $0.01
- Minimum topup: $2.00
- Signup credit (phone auth only): $20.00

## Example Calculations

### Web App (0.1 core, 128Mi memory)

- Compute: 0.1 * $0.04 = $0.004/hr
- Memory: 0.125 * $0.005 = $0.000625/hr
- Total: $0.004625/hr = $0.111/day = $3.38/month

### Database (0.25 core, 512Mi memory, 10GB storage)

- Compute: 0.25 * $0.04 = $0.01/hr
- Memory: 0.5 * $0.005 = $0.0025/hr
- Storage: 10 * $0.0001 = $0.001/hr
- Total: $0.0135/hr = $0.324/day = $9.86/month

### Full Stack (web + database + cache)

- Web: $0.004625/hr
- Database: $0.0135/hr
- Cache (0.1 core, 256Mi): $0.00166/hr
- Total: $0.01979/hr = $0.475/day = $14.44/month

## Balance Duration Table

How long will your credits last at various burn rates:

| Balance | Hourly Cost | Duration |
|---------|-------------|----------|
| $5.00 | $0.005 | ~1000 hours (41 days) |
| $5.00 | $0.02 | ~250 hours (10 days) |
| $5.00 | $0.05 | ~100 hours (4 days) |
| $20.00 | $0.02 | ~1000 hours (41 days) |
| $20.00 | $0.05 | ~400 hours (16 days) |

## Payment Chains

| Chain | USDC | USDT | Decimals |
|-------|------|------|----------|
| Ethereum | Yes | Yes | 6 |
| Base | Yes | Yes | 6 |
| Arbitrum | Yes | Yes | 6 |
| Optimism | Yes | Yes | 6 |
| Polygon | Yes | Yes | 6 |
| BSC | Yes | Yes | 18 |

Note: BSC uses 18 decimals while all other chains use 6 decimals for both USDC and USDT.
