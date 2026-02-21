#!/usr/bin/env bash
# Check that required tools are installed for Willform Agent plugin.
# Exit 0 if all OK, exit 1 with list of missing items otherwise.

set -euo pipefail

missing=()

# Required: curl, jq
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    missing+=("$cmd")
  fi
done

# Optional but recommended: docker, gh
warnings=()
if ! command -v docker &>/dev/null; then
  warnings+=("docker — needed for /wf-build-push")
fi
if ! command -v gh &>/dev/null; then
  warnings+=("gh (GitHub CLI) — needed for GHCR auth in /wf-build-push")
fi

# API key check
config_file="${HOME}/.claude/willform-plugins.local.md"
if [[ -z "${WF_API_KEY:-}" ]] && [[ ! -f "$config_file" ]]; then
  warnings+=("Willform API key not configured — run /wf-setup")
fi

# Report
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "MISSING required tools:"
  for item in "${missing[@]}"; do
    echo "  - $item"
  done
  exit 1
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
  echo "WARNINGS (optional):"
  for item in "${warnings[@]}"; do
    echo "  - $item"
  done
fi

echo "All prerequisites OK."
exit 0
