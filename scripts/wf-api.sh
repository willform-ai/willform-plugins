#!/usr/bin/env bash
# Shared API helper for Willform Agent REST API calls.
# Source this file from commands, then call wf_get / wf_post / wf_put / wf_delete.
#
# Expects either:
#   - WF_API_KEY env var (wf_sk_* format)
#   - Or a config file at ~/.claude/willform-plugins.local.md with api_key / base_url

set -euo pipefail

# ── Config loading ────────────────────────────────────────────────────────────

_WF_CONFIG_FILE="${HOME}/.claude/willform-plugins.local.md"
_WF_DEFAULT_BASE_URL="https://agent.willform.ai"

wf_load_config() {
  if [[ -z "${WF_API_KEY:-}" ]] && [[ -f "$_WF_CONFIG_FILE" ]]; then
    WF_API_KEY=$(sed -n 's/^api_key:[[:space:]]*//p' "$_WF_CONFIG_FILE" | tr -d '[:space:]')
    WF_BASE_URL=$(sed -n 's/^base_url:[[:space:]]*//p' "$_WF_CONFIG_FILE" | tr -d '[:space:]')
  fi

  WF_BASE_URL="${WF_BASE_URL:-$_WF_DEFAULT_BASE_URL}"

  if [[ -z "${WF_LANGUAGE:-}" ]] && [[ -f "$_WF_CONFIG_FILE" ]]; then
    WF_LANGUAGE=$(sed -n 's/^language:[[:space:]]*//p' "$_WF_CONFIG_FILE" | tr -d '[:space:]')
  fi
  WF_LANGUAGE="${WF_LANGUAGE:-}"

  if [[ -z "${WF_API_KEY:-}" ]]; then
    echo "ERROR: WF_API_KEY not set. Run /wf-setup first." >&2
    return 1
  fi
}

# ── HTTP helpers ──────────────────────────────────────────────────────────────

_wf_request() {
  local method="$1"
  local path="$2"
  shift 2
  local body="${1:-}"

  local url="${WF_BASE_URL}${path}"
  local -a curl_args=(
    -s -w '\n%{http_code}'
    -X "$method"
    -H "Authorization: Bearer ${WF_API_KEY}"
    -H "Content-Type: application/json"
    -H "Accept: application/json"
  )

  if [[ -n "$body" ]]; then
    curl_args+=(-d "$body")
  fi

  local response
  response=$(curl "${curl_args[@]}" "$url" 2>/dev/null) || {
    echo "ERROR: Failed to connect to ${url}" >&2
    return 1
  }

  local http_code
  http_code=$(echo "$response" | tail -1)
  local body_text
  body_text=$(echo "$response" | sed '$d')

  if [[ "$http_code" -ge 400 ]]; then
    local error_msg
    error_msg=$(echo "$body_text" | jq -r '.error // .message // "Unknown error"' 2>/dev/null || echo "$body_text")
    echo "ERROR: HTTP ${http_code} — ${error_msg}" >&2
    return 1
  fi

  echo "$body_text"
}

wf_get()    { _wf_request GET    "$1"; }
wf_post()   { _wf_request POST   "$1" "${2:-}"; }
wf_put()    { _wf_request PUT    "$1" "${2:-}"; }
wf_delete() { _wf_request DELETE "$1"; }

# ── JSON helpers ──────────────────────────────────────────────────────────────

wf_json_field() {
  local json="$1"
  local field="$2"
  echo "$json" | jq -r ".$field // empty"
}

wf_json_success() {
  local json="$1"
  echo "$json" | jq -r '.success // false'
}
