# Language Guidelines for Willform Plugin

All user-invocable skills should respect the user's language preference stored in `~/.claude/willform-plugins.local.md` as the `language:` field.

## How to Read Language Preference

After sourcing `wf-api.sh` and calling `wf_load_config`, the `WF_LANGUAGE` env var is set:
- `en` — English
- `ko` — Korean (한국어)
- empty — not configured yet

## Behavior

### If `WF_LANGUAGE` is set
Use the configured language for all output: status messages, error messages, tables, and summaries.

### If `WF_LANGUAGE` is empty
On the first interaction, ask the user to choose their preferred language before proceeding. Save their choice to the config file.

## Output Style by Language

### English
- Use concise, technical language
- Status labels: "running", "stopped", "failed", "suspended"
- Error prefix: "Error:"
- Success prefix: none (just show the result)

### Korean (한국어)
- Use natural Korean with technical terms in English
- Status labels: keep English ("running", "stopped" etc.) — these are K8s-native terms
- Error prefix: "오류:"
- Success prefix: none
- Keep variable names, API paths, and code in English
- Translate explanations and instructions to Korean

## Setting Language via /wf-setup

`/wf-setup` includes a language selection step. The config file format:

```
api_key: wf_sk_...
base_url: https://agent.willform.ai
language: ko
```
