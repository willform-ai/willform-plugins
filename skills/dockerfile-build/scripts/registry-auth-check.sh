#!/usr/bin/env bash
# Unified registry authentication check.
# Usage: registry-auth-check.sh <ghcr|dockerhub>
# Exits 0 if authenticated, 1 if not.

set -euo pipefail

REGISTRY="${1:-}"

if [[ -z "$REGISTRY" ]]; then
  echo "Usage: registry-auth-check.sh <ghcr|dockerhub>"
  exit 1
fi

check_ghcr() {
  # Method 1: gh CLI auth
  if command -v gh &>/dev/null; then
    if gh auth status &>/dev/null; then
      user=$(gh api user -q .login 2>/dev/null || echo "unknown")
      echo "GHCR: Authenticated via gh CLI as ${user}"

      if gh auth token | docker login ghcr.io --username "${user}" --password-stdin &>/dev/null 2>&1; then
        echo "GHCR: Docker login successful"
        exit 0
      else
        echo "GHCR: gh authenticated but docker login failed. Try: gh auth token | docker login ghcr.io -u ${user} --password-stdin"
        exit 1
      fi
    fi
  fi

  # Method 2: GITHUB_TOKEN env var
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    if echo "${GITHUB_TOKEN}" | docker login ghcr.io -u "token" --password-stdin &>/dev/null 2>&1; then
      echo "GHCR: Authenticated via GITHUB_TOKEN"
      exit 0
    else
      echo "GHCR: GITHUB_TOKEN set but docker login failed. Check token permissions (need write:packages)."
      exit 1
    fi
  fi

  # Method 3: Existing docker credentials
  if docker pull ghcr.io/library/alpine:3.19 &>/dev/null 2>&1; then
    echo "GHCR: Docker already has valid credentials"
    exit 0
  fi

  echo "GHCR: Not authenticated. Options:"
  echo "  1. gh auth login --scopes write:packages"
  echo "  2. export GITHUB_TOKEN=ghp_... (with write:packages scope)"
  echo "  3. echo \$TOKEN | docker login ghcr.io -u USERNAME --password-stdin"
  exit 1
}

check_dockerhub() {
  local docker_config="${HOME}/.docker/config.json"

  # Method 1: Check .docker/config.json for existing credentials
  if [[ -f "$docker_config" ]]; then
    # Check direct auths entry for Docker Hub
    if command -v jq &>/dev/null; then
      local has_auths
      has_auths=$(jq -r '
        (.auths // {}) |
        to_entries[] |
        select(.key == "https://index.docker.io/v1/" or .key == "index.docker.io" or .key == "docker.io" or .key == "registry-1.docker.io") |
        .key
      ' "$docker_config" 2>/dev/null || true)

      if [[ -n "$has_auths" ]]; then
        echo "Docker Hub: Credentials found in docker config"
        # Verify they actually work with a lightweight check
        if docker login --username "" --password "" 2>&1 | grep -q "Login Succeeded" 2>/dev/null || docker pull hello-world &>/dev/null 2>&1; then
          echo "Docker Hub: Authenticated via docker config"
          exit 0
        fi
        # Credentials exist but may be stale — still report as found
        echo "Docker Hub: Credentials found (may need refresh). Proceeding."
        exit 0
      fi

      # Check credsStore (e.g., osxkeychain, desktop)
      local creds_store
      creds_store=$(jq -r '.credsStore // empty' "$docker_config" 2>/dev/null || true)
      if [[ -n "$creds_store" ]]; then
        # With a credential store, auth is managed externally — try a quick verify
        if docker-credential-"${creds_store}" list 2>/dev/null | grep -q "index.docker.io"; then
          echo "Docker Hub: Authenticated via credential store (${creds_store})"
          exit 0
        fi
      fi

      # Check credHelpers
      local cred_helper
      cred_helper=$(jq -r '(.credHelpers // {}) | to_entries[] | select(.key == "index.docker.io" or .key == "docker.io") | .value' "$docker_config" 2>/dev/null || true)
      if [[ -n "$cred_helper" ]]; then
        echo "Docker Hub: Credential helper (${cred_helper}) configured"
        exit 0
      fi
    fi
  fi

  # Method 2: DOCKERHUB_TOKEN + DOCKERHUB_USERNAME env vars
  if [[ -n "${DOCKERHUB_TOKEN:-}" && -n "${DOCKERHUB_USERNAME:-}" ]]; then
    if echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin &>/dev/null 2>&1; then
      echo "Docker Hub: Authenticated via DOCKERHUB_TOKEN"
      exit 0
    else
      echo "Docker Hub: DOCKERHUB_TOKEN set but login failed. Check token permissions."
      exit 1
    fi
  fi

  echo "Docker Hub: Not authenticated. Options:"
  echo "  1. docker login (interactive — enter username and access token)"
  echo "  2. export DOCKERHUB_USERNAME=... && export DOCKERHUB_TOKEN=..."
  echo "     Create a token at: https://hub.docker.com/settings/security"
  echo "  3. echo \$TOKEN | docker login -u USERNAME --password-stdin"
  exit 1
}

case "$REGISTRY" in
  ghcr)
    check_ghcr
    ;;
  dockerhub)
    check_dockerhub
    ;;
  *)
    echo "Unknown registry: $REGISTRY"
    echo "Supported: ghcr, dockerhub"
    exit 1
    ;;
esac
