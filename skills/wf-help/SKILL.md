---
name: wf-help
description: Show all Willform plugin commands and usage guide
allowed-tools: Bash, Read
user-invocable: true
---

# /wf-help — Willform Plugin Guide

## Language Selection

Before showing help content, check the language preference:

1. Source the config:
```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config 2>/dev/null
```

2. Read `WF_LANGUAGE` from the loaded config. If empty or not set, use AskUserQuestion:
   - "Which language do you prefer for Willform output? / Willform 출력 언어를 선택하세요."
   - Options: "English (Recommended)" / "한국어"
   - Save the selection to `~/.claude/willform-plugins.local.md` by appending `language: en` or `language: ko`

3. Use the selected language for ALL output below.

## Help Content

Display the following guide in the user's preferred language.

### English Version

```
Willform Agent — CLI Plugin for Kubernetes Deployment

What You Need:
  1. Willform API key     → Run /wf-setup to configure
  2. Telegram bot token   → Create via @BotFather in Telegram
  3. LLM API key          → From OpenRouter, OpenAI, Anthropic, or Google

Getting Started:
  /wf-setup              Configure API key and base URL
  /wf-help               Show this guide

Deploy:
  /wf-deploy-openclaw    Deploy an OpenClaw AI agent with Telegram bot
                         Guides you through: Telegram setup → LLM provider
                         → soul preset → gateway token → deploy.
  /wf-build-push         Build Docker image and push to GHCR or Docker Hub

Monitor:
  /wf-status             Check deployment status (all or specific)
  /wf-status <name>      Detailed status for a specific deployment
  /wf-logs <name>        View container logs for a deployment

Billing:
  /wf-cost               Credit balance and burn rate estimate

Quick Start:
  1. /wf-setup                Set your Willform API key
  2. /wf-deploy-openclaw      Deploy an AI agent (Telegram bot + LLM key
                              + soul selection + gateway token)
  3. Open https://{domain}/?token={gateway_token} to pair your device
  4. Chat via https://t.me/your_bot_username or the web dashboard
  5. /wf-status               Verify it's running
  6. /wf-cost                 Check your spending

Supported LLM Providers:
  OpenRouter (Recommended)  All models with one key — openrouter.ai/keys
  OpenAI                    GPT-4o, GPT-4o-mini — platform.openai.com/api-keys
  Anthropic                 Claude Sonnet, Haiku — console.anthropic.com/settings/keys
  Google Gemini             Gemini 2.0 Flash/Pro — aistudio.google.com/apikey

Pricing:
  Compute  $0.04/core/hr
  Memory   $0.005/GB/hr
  Storage  $0.0001/GB/hr

API:      https://agent.willform.ai
Docs:     https://agent.willform.ai/docs
```

### Korean Version

```
Willform Agent — Kubernetes 배포 CLI 플러그인

준비물:
  1. Willform API 키     → /wf-setup 으로 설정
  2. Telegram 봇 토큰    → Telegram에서 @BotFather로 생성
  3. LLM API 키          → OpenRouter, OpenAI, Anthropic, Google 중 택 1

시작하기:
  /wf-setup              API 키 및 기본 URL 설정
  /wf-help               이 가이드 표시

배포:
  /wf-deploy-openclaw    Telegram 봇 + AI 에이전트 배포
                         Telegram 설정 → LLM 선택 → soul 역할 선택
                         → gateway 토큰 → 배포까지 안내합니다.
  /wf-build-push         Docker 이미지 빌드 및 GHCR/Docker Hub 푸시

모니터링:
  /wf-status             배포 상태 확인 (전체 또는 특정 배포)
  /wf-status <이름>      특정 배포의 상세 상태
  /wf-logs <이름>        배포 컨테이너 로그 조회

비용:
  /wf-cost               크레딧 잔액 및 소비율 예측

빠른 시작:
  1. /wf-setup                Willform API 키 설정
  2. /wf-deploy-openclaw      AI 에이전트 배포 (Telegram 봇 + LLM 키
                              + soul 역할 선택 + gateway 토큰)
  3. https://{도메인}/?token={gateway_token} 으로 디바이스 페어링
  4. https://t.me/봇_username 또는 웹 대시보드에서 에이전트와 대화
  5. /wf-status               실행 상태 확인
  6. /wf-cost                 비용 확인

지원 LLM 프로바이더:
  OpenRouter (추천)       모든 모델 하나의 키로 — openrouter.ai/keys
  OpenAI                  GPT-4o, GPT-4o-mini — platform.openai.com/api-keys
  Anthropic               Claude Sonnet, Haiku — console.anthropic.com/settings/keys
  Google Gemini           Gemini 2.0 Flash/Pro — aistudio.google.com/apikey

요금:
  컴퓨팅   $0.04/코어/시간
  메모리   $0.005/GB/시간
  스토리지 $0.0001/GB/시간

API:      https://agent.willform.ai
문서:     https://agent.willform.ai/docs
```

### Additional Info

If the user asks about a specific command, read the corresponding SKILL.md and provide a summary:
- `/wf-setup`: `skills/wf-setup/SKILL.md`
- `/wf-deploy-openclaw`: `skills/wf-deploy-openclaw/SKILL.md`
- `/wf-build-push`: `skills/wf-build-push/SKILL.md`
- `/wf-status`: `skills/wf-status/SKILL.md`
- `/wf-logs`: `skills/wf-logs/SKILL.md`
- `/wf-cost`: `skills/wf-cost/SKILL.md`

If the API key is not configured yet, suggest running `/wf-setup` first.
