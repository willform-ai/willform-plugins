#!/usr/bin/env bash
# Shared API helper for Willform Agent.
# Source this file from skills, then call the helpers below.
#
# REST:  wf_get, wf_post, wf_put, wf_delete — standard CRUD endpoints
# MCP:   wf_mcp — MCP JSON-RPC tools via /api/mcp (SSE response, auto-parsed)
# JSON:  wf_json_field, wf_json_success — response parsing
# Config: wf_load_config — reads api_key, base_url, language from config file
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

  # Extract HTTP status code (last line) and body (everything before it).
  # Using bash parameter expansion instead of tail/sed for robustness
  # with empty responses and multi-line bodies.
  local http_code
  http_code="${response##*$'\n'}"
  local body_text
  if [[ "$response" == *$'\n'* ]]; then
    body_text="${response%$'\n'*}"
  else
    body_text=""
  fi

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

# MCP JSON-RPC helper — calls tools via /api/mcp with the required Accept header.
# The MCP endpoint returns SSE (Server-Sent Events) format: "event: message\ndata: {json}\n"
# Usage: wf_mcp <tool_name> '<json_arguments>'
# Returns: the text content from result.content[0].text
wf_mcp() {
  local tool_name="$1"
  local arguments="${2:-\{\}}"

  local mcp_body
  mcp_body=$(jq -n \
    --arg name "$tool_name" \
    --argjson args "$arguments" \
    '{jsonrpc:"2.0",method:"tools/call",params:{name:$name,arguments:$args},id:1}')

  local url="${WF_BASE_URL}/api/mcp"
  local raw_response
  raw_response=$(curl -s -w '\n%{http_code}' -X POST \
    -H "Authorization: Bearer ${WF_API_KEY}" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d "$mcp_body" "$url" 2>/dev/null) || {
    echo "ERROR: Failed to connect to ${url}" >&2
    return 1
  }

  local http_code
  http_code=$(echo "$raw_response" | tail -1)

  if [[ "$http_code" -ge 400 ]]; then
    local error_body
    error_body=$(echo "$raw_response" | sed '$d')
    local error_msg
    error_msg=$(echo "$error_body" | jq -r '.error.message // .error // .message // "Unknown error"' 2>/dev/null || echo "$error_body")
    echo "ERROR: HTTP ${http_code} — ${error_msg}" >&2
    return 1
  fi

  # Parse SSE format: extract JSON from "data: " lines
  local json_data
  json_data=$(echo "$raw_response" | sed -n 's/^data: //p' | head -1)

  # Fallback: if not SSE, try parsing entire body as JSON
  if [[ -z "$json_data" ]]; then
    json_data=$(echo "$raw_response" | sed '$d')
  fi

  # Check for JSON-RPC error
  local has_error
  has_error=$(echo "$json_data" | jq -r '.error // empty' 2>/dev/null)
  if [[ -n "$has_error" ]]; then
    local err_msg
    err_msg=$(echo "$json_data" | jq -r '.error.message // .error' 2>/dev/null)
    echo "ERROR: MCP — ${err_msg}" >&2
    return 1
  fi

  echo "$json_data" | jq -r '.result.content[0].text // empty' 2>/dev/null
}

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
