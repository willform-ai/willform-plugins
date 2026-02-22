#!/usr/bin/env bash
# SessionStart hook — loads Willform API config into environment context.
# Outputs key-value pairs that Claude Code injects as session context.

set -euo pipefail

# Check required tools
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Willform: '$cmd' is required but not installed."
    exit 0
  fi
done

config_file="${HOME}/.claude/willform-plugins.local.md"

if [[ ! -f "$config_file" ]]; then
  echo "Willform: API key not configured. Run /wf-setup to get started."
  exit 0
fi

api_key=$(sed -n 's/^api_key:[[:space:]]*//p' "$config_file" | tr -d '[:space:]')
base_url=$(sed -n 's/^base_url:[[:space:]]*//p' "$config_file" | tr -d '[:space:]')
base_url="${base_url:-https://agent.willform.ai}"

if [[ -z "$api_key" ]]; then
  echo "Willform: api_key is empty in config. Run /wf-setup to reconfigure."
  exit 0
fi

# Validate key format
if [[ ! "$api_key" =~ ^wf_sk_ ]]; then
  echo "Willform: Invalid API key format (expected wf_sk_*). Run /wf-setup."
  exit 0
fi

# Quick connectivity check
http_code=$(curl -s -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer ${api_key}" \
  "${base_url}/api/health" 2>/dev/null || echo "000")

if [[ "$http_code" == "200" ]]; then
  echo "Willform Agent connected (${base_url})"
else
  echo "Willform: Cannot reach ${base_url} (HTTP ${http_code}). Check network or base_url."
fi
