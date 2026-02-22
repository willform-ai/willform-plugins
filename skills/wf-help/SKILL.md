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
source scripts/wf-api.sh && wf_load_config 2>/dev/null
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

Getting Started:
  /wf-setup              Configure API key and base URL
  /wf-help               Show this guide

Deploy:
  /wf-deploy-openclaw    Deploy an OpenClaw AI agent (with soul presets)
  /wf-build-push         Build Docker image and push to GHCR

Monitor:
  /wf-status             Check deployment status (all or specific)
  /wf-status <name>      Detailed status for a specific deployment
  /wf-logs <name>        View container logs for a deployment

Billing:
  /wf-cost               Credit balance and burn rate estimate

Quick Start:
  1. /wf-setup            Set your API key
  2. /wf-deploy-openclaw  Deploy an AI agent
  3. /wf-status           Verify it's running
  4. /wf-cost             Check your spending

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

시작하기:
  /wf-setup              API 키 및 기본 URL 설정
  /wf-help               이 가이드 표시

배포:
  /wf-deploy-openclaw    OpenClaw AI 에이전트 배포 (soul 프리셋 지원)
  /wf-build-push         Docker 이미지 빌드 및 GHCR 푸시

모니터링:
  /wf-status             배포 상태 확인 (전체 또는 특정 배포)
  /wf-status <이름>      특정 배포의 상세 상태
  /wf-logs <이름>        배포 컨테이너 로그 조회

비용:
  /wf-cost               크레딧 잔액 및 소비율 예측

빠른 시작:
  1. /wf-setup            API 키 설정
  2. /wf-deploy-openclaw  AI 에이전트 배포
  3. /wf-status           실행 상태 확인
  4. /wf-cost             비용 확인

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
