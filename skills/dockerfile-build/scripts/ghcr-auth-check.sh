#!/usr/bin/env bash
# Check GHCR authentication status.
# Exits 0 if authenticated, 1 if not.

set -euo pipefail

# Method 1: Check gh CLI auth
if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null; then
    user=$(gh api user -q .login 2>/dev/null || echo "unknown")
    echo "GHCR: Authenticated via gh CLI as ${user}"

    # Check if docker credential helper is configured for ghcr.io
    if gh auth token | docker login ghcr.io --username "${user}" --password-stdin &>/dev/null 2>&1; then
      echo "GHCR: Docker login successful"
      exit 0
    else
      echo "GHCR: gh authenticated but docker login failed. Try: gh auth token | docker login ghcr.io -u ${user} --password-stdin"
      exit 1
    fi
  fi
fi

# Method 2: Check GITHUB_TOKEN env var
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  if echo "${GITHUB_TOKEN}" | docker login ghcr.io -u "token" --password-stdin &>/dev/null 2>&1; then
    echo "GHCR: Authenticated via GITHUB_TOKEN"
    exit 0
  else
    echo "GHCR: GITHUB_TOKEN set but docker login failed. Check token permissions (need write:packages)."
    exit 1
  fi
fi

# Method 3: Check existing docker credentials
if docker pull ghcr.io/library/alpine:3.19 &>/dev/null 2>&1; then
  echo "GHCR: Docker already has valid credentials"
  exit 0
fi

echo "GHCR: Not authenticated. Options:"
echo "  1. gh auth login --scopes write:packages"
echo "  2. export GITHUB_TOKEN=ghp_... (with write:packages scope)"
echo "  3. echo \$TOKEN | docker login ghcr.io -u USERNAME --password-stdin"
exit 1
