---
name: dockerfile-build
description: Generate Dockerfiles, build images, and push to GHCR for Willform deployment
---

# Dockerfile Build & Push to GHCR

Analyze a project, generate an optimized Dockerfile, build a Docker image, and push it to GitHub Container Registry (GHCR) for deployment on Willform Agent.

## Prerequisites

- Docker installed and running (`docker info` should succeed)
- GitHub CLI (`gh`) authenticated OR `GITHUB_TOKEN` environment variable set with `write:packages` scope
- Project source code in the current working directory

## Workflow

1. **Detect project type**
   Scan the working directory for project markers:
   - `package.json` → Node.js (check for `pnpm-lock.yaml`, `yarn.lock`, or `package-lock.json` to determine package manager)
   - `requirements.txt` / `pyproject.toml` / `Pipfile` → Python
   - `go.mod` → Go
   - `Cargo.toml` → Rust
   - `pom.xml` / `build.gradle` / `build.gradle.kts` → Java
   - `Gemfile` → Ruby
   - `index.html` (no other markers) → Static site

2. **Generate Dockerfile**
   Use multi-stage build patterns from `references/dockerfile-patterns.md`. If a Dockerfile already exists, ask the user whether to use the existing one or generate a new one.

3. **Generate .dockerignore**
   Create a `.dockerignore` if one does not exist. Include common exclusions: `.git`, `node_modules`, `__pycache__`, `.env`, `.vscode`, `.idea`, `target`, `dist` (when separate from build output).

4. **Build image**
   ```bash
   docker build --platform linux/amd64 -t ghcr.io/{owner}/{repo}:{tag} .
   ```

5. **Authenticate to GHCR**
   Run `scripts/ghcr-auth-check.sh` to verify authentication. If not authenticated:
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u {user} --password-stdin
   ```
   Or via gh CLI:
   ```bash
   gh auth token | docker login ghcr.io -u $(gh api user -q .login) --password-stdin
   ```

6. **Push image**
   ```bash
   docker push ghcr.io/{owner}/{repo}:{tag}
   ```

7. **Verify**
   ```bash
   docker manifest inspect ghcr.io/{owner}/{repo}:{tag}
   ```
   Confirm the manifest includes `linux/amd64` platform.

## Important Notes

- **Platform requirement**: Willform Agent runs on EKS with amd64 nodes. Always use `--platform linux/amd64` when building, especially on ARM Macs (Apple Silicon).
- **Image visibility**: The image must be public, or the user must provide `imagePullSecretName` when deploying via Willform Agent. GHCR images default to private — make public via GitHub package settings if needed.
- **Port alignment**: The default port in the Dockerfile `EXPOSE` directive should match what the user specifies (or the chart type default) at deploy time. Willform preflight checks warn on port mismatches.
- **Tag strategy**: Use the short git SHA (`git rev-parse --short HEAD`) as the image tag. This provides traceability back to the exact commit. Fall back to `latest` only when not in a git repository.
- **Image size**: Multi-stage builds keep final images small. Avoid copying build tools, test files, or dev dependencies into the final stage.
