---
name: wf-template
description: Browse and deploy from templates on Willform Agent
allowed-tools: Bash, Read, AskUserQuestion
user-invocable: true
---

# /wf-template -- Browse & Deploy Templates

## Goal

Browse available deployment templates and deploy directly from a template on Willform Agent. Templates are stored in the `willform-ai/willform-templates` GitHub repo and provide pre-configured settings for common applications.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

### Step 1: Load API config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config
```

If this fails, tell the user to run `/wf-setup` first and stop.

### Step 2: Determine action

If an argument is provided (`$ARGUMENTS`), treat it as a template name to deploy.

Otherwise, use AskUserQuestion:
- **Browse templates** — List available templates
- **Deploy from template** — Pick a template and deploy it

### Step 3: Browse templates

Templates are fetched directly from GitHub (no REST API endpoint):

```bash
response=$(curl -sf "https://api.github.com/repos/willform-ai/willform-templates/contents/templates" \
  -H "Accept: application/vnd.github.v3+json")
```

Parse the directory listing to get template names (each `.md` file is a template).

For each template, fetch its content to extract the YAML frontmatter:

```bash
raw=$(curl -sf "https://raw.githubusercontent.com/willform-ai/willform-templates/main/templates/${TEMPLATE_FILE}")
```

Display templates grouped by category:

```
Templates:

  Web Applications:
    nextjs          Next.js starter app
    express         Express.js API server
    nginx           Static file server

  Databases:
    postgresql      PostgreSQL 16
    mysql           MySQL 8
    redis           Redis 7 cache

  AI/ML:
    openclaw        OpenClaw AI agent with gateway
```

If GitHub is unreachable, show the built-in chart types as a fallback:

```bash
response=$(wf_mcp "chart_list" "{}")
```

### Step 4: Deploy from template

When a template is selected:

1. Fetch the template markdown and parse its frontmatter for default values (image, port, chartType, env, volume)

2. Use AskUserQuestion to let the user customize:
   - **App name** (required): Suggest based on template name
   - **Environment variables**: Show template defaults, allow override
   - **Namespace**: Select existing or create new (`GET /api/namespaces`)

3. Deploy using the template deploy REST endpoint:

```bash
DEPLOY_BODY=$(jq -n \
  --arg nsId "$NAMESPACE_ID" \
  --arg templateId "$TEMPLATE_ID" \
  --arg message "Deploy ${TEMPLATE_NAME} with custom config" \
  --argjson values "$VALUES_JSON" \
  '{
    namespaceId: $nsId,
    templateId: $templateId,
    message: $message,
    values: $values
  }')

response=$(wf_post "/api/templates/deploy" "$DEPLOY_BODY")
JOB_ID=$(wf_json_field "$response" "data.jobId")
```

4. Poll for completion:

```bash
for i in $(seq 1 24); do
  RESULT=$(wf_get "/api/templates/deploy?jobId=${JOB_ID}")
  STATUS=$(wf_json_field "$RESULT" "data.status")
  if [[ "$STATUS" == "completed" ]]; then break; fi
  if [[ "$STATUS" == "failed" ]]; then
    ERROR=$(wf_json_field "$RESULT" "data.error")
    echo "Template deployment failed: $ERROR"
    break
  fi
  sleep 5
done
```

### Step 5: Report result

**On success:**

```
Template deployed successfully.

  Template:  {template_name}
  Status:    {status}

Next steps:
  /wf-status           Check deployment status
  /wf-logs <name>      View container logs
  /wf-domain <name>    Expose with custom domain
```

**On failure:**

Show the error from the job result and suggest checking logs.

## Error Handling

- If API returns 401, suggest `/wf-setup`
- If GitHub is unreachable, fall back to `chart_list` MCP tool for available chart types and suggest using `/wf-deploy` for manual deployment instead
- If template deploy job fails, show the error and suggest `/wf-deploy` as a manual alternative
- If template not found in the repo, list available templates
