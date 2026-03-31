---
name: wf-help
description: Show all Willform plugin commands and usage guide
allowed-tools: Bash, Read
user-invocable: true
---

# /wf-help -- Willform Plugin Guide

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
  2. Container image      → Use /wf-build-push to build, or use a public image

Getting Started:
  /wf-setup              Configure API key and base URL
  /wf-help               Show this guide

Deploy:
  /wf-deploy             Deploy any container to Willform Agent
  /wf-template           Browse and deploy from pre-built templates
  /wf-build-push         Build Docker image and push to GHCR or Docker Hub

Monitor:
  /wf-status             Check deployment status (all or specific)
  /wf-logs <name>        View container logs for a deployment
  /wf-monitor            Deployment health check and issue diagnosis
  /wf-diagnose <name>    Deep diagnosis with logs, events, and fixes

Manage:
  /wf-namespace          List, create, update, or delete namespaces
  /wf-scale <name>       Scale, stop, restart, or delete a deployment
  /wf-env <name>         View or update environment variables
  /wf-domain             Expose deployments and manage custom domains

Billing:
  /wf-cost               Credit balance and burn rate estimate
  /wf-credits            Deposit options and transaction verification

Agent:
  /wf-agent              Interact with Willy AI agent

Integration:
  /wf-apm                Deploy MCP servers from apm.yml manifest

Quick Start:
  1. /wf-setup                Set your Willform API key
  2. /wf-build-push           Build and push your Docker image (if custom)
  3. /wf-deploy               Deploy a container
  4. /wf-status               Verify it's running
  5. /wf-cost                 Check your spending

Pricing:
  Compute  $0.04/core/hr
  Memory   $0.01/GB/hr
  Storage  $0.00018/GB/hr

Note: Minimum runway policy — you need at least 2 hours of runway
  (balance / burn rate >= 2h) to create or expand resources.
  Error: INSUFFICIENT_RUNWAY (402). Top up credits to continue.

API:      https://agent.willform.ai
Docs:     https://agent.willform.ai/docs
```

### Korean Version

```
Willform Agent — Kubernetes 배포 CLI 플러그인

준비물:
  1. Willform API 키     → /wf-setup 으로 설정
  2. 컨테이너 이미지      → /wf-build-push로 빌드하거나 공개 이미지 사용

시작하기:
  /wf-setup              API 키 및 기본 URL 설정
  /wf-help               이 가이드 표시

배포:
  /wf-deploy             Willform Agent에 컨테이너 배포
  /wf-template           템플릿 목록 조회 및 배포
  /wf-build-push         Docker 이미지 빌드 및 GHCR/Docker Hub 푸시

모니터링:
  /wf-status             배포 상태 확인 (전체 또는 특정 배포)
  /wf-logs <이름>        배포 컨테이너 로그 조회
  /wf-monitor            배포 헬스 체크 및 문제 진단
  /wf-diagnose <이름>    로그·이벤트 기반 상세 진단

관리:
  /wf-namespace          네임스페이스 목록, 생성, 수정, 삭제
  /wf-scale <이름>       배포 스케일링, 중지, 재시작, 삭제
  /wf-env <이름>         환경변수 조회 및 수정
  /wf-domain             배포 도메인 노출 및 커스텀 도메인 관리

비용:
  /wf-cost               크레딧 잔액 및 소비율 예측
  /wf-credits            입금 옵션 및 트랜잭션 확인

에이전트:
  /wf-agent              Willy AI 에이전트 상호작용

통합:
  /wf-apm                apm.yml 매니페스트에서 MCP 서버 배포

빠른 시작:
  1. /wf-setup                Willform API 키 설정
  2. /wf-build-push           Docker 이미지 빌드 및 푸시 (커스텀 앱인 경우)
  3. /wf-deploy               컨테이너 배포
  4. /wf-status               실행 상태 확인
  5. /wf-cost                 비용 확인

요금:
  컴퓨팅   $0.04/코어/시간
  메모리   $0.01/GB/시간
  스토리지 $0.00018/GB/시간

참고: 최소 runway 정책 — 리소스를 생성하거나 확장하려면
  최소 2시간의 runway(잔액 / 소비율 >= 2시간)가 필요합니다.
  오류: INSUFFICIENT_RUNWAY (402). 크레딧을 충전하세요.

API:      https://agent.willform.ai
문서:     https://agent.willform.ai/docs
```

### Additional Info

If the user asks about a specific command, read the corresponding SKILL.md and provide a summary:
- `/wf-help`: `skills/wf-help/SKILL.md`
- `/wf-setup`: `skills/wf-setup/SKILL.md`
- `/wf-deploy`: `skills/wf-deploy/SKILL.md`
- `/wf-template`: `skills/wf-template/SKILL.md`
- `/wf-build-push`: `skills/wf-build-push/SKILL.md`
- `/wf-status`: `skills/wf-status/SKILL.md`
- `/wf-logs`: `skills/wf-logs/SKILL.md`
- `/wf-monitor`: `skills/wf-monitor/SKILL.md`
- `/wf-diagnose`: `skills/wf-diagnose/SKILL.md`
- `/wf-namespace`: `skills/wf-namespace/SKILL.md`
- `/wf-scale`: `skills/wf-scale/SKILL.md`
- `/wf-env`: `skills/wf-env/SKILL.md`
- `/wf-domain`: `skills/wf-domain/SKILL.md`
- `/wf-cost`: `skills/wf-cost/SKILL.md`
- `/wf-credits`: `skills/wf-credits/SKILL.md`
- `/wf-agent`: `skills/wf-agent/SKILL.md`
- `/wf-apm`: `skills/wf-apm/SKILL.md`

If the API key is not configured yet, suggest running `/wf-setup` first.
