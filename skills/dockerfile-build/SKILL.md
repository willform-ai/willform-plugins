---
name: dockerfile-build
description: Generate Dockerfiles, build images, and push to GHCR or Docker Hub for Willform deployment
---

# Dockerfile Build & Push

Analyze a project, generate an optimized Dockerfile, build a Docker image, and push it to GitHub Container Registry (GHCR) or Docker Hub for deployment on Willform Agent.

## Prerequisites

- Docker installed and running (`docker info` should succeed)
- For GHCR: GitHub CLI (`gh`) authenticated OR `GITHUB_TOKEN` environment variable set with `write:packages` scope
- For Docker Hub: `docker login` completed OR `DOCKERHUB_TOKEN` + `DOCKERHUB_USERNAME` environment variables set
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

5. **Authenticate to registry**
   Run `scripts/registry-auth-check.sh ghcr` or `scripts/registry-auth-check.sh dockerhub` to verify authentication.

   **GHCR** — If not authenticated:
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u {user} --password-stdin
   ```
   Or via gh CLI:
   ```bash
   gh auth token | docker login ghcr.io -u $(gh api user -q .login) --password-stdin
   ```

   **Docker Hub** — If not authenticated:
   ```bash
   docker login
   ```
   Or with environment variables:
   ```bash
   echo $DOCKERHUB_TOKEN | docker login -u $DOCKERHUB_USERNAME --password-stdin
   ```
   Create a token at: https://hub.docker.com/settings/security

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
- **Multi-registry support**: When deploying via the Willform Agent API, provide `registryAuth` with the correct server value: `"ghcr.io"` for GHCR, `"https://index.docker.io/v1/"` for Docker Hub. The `/wf-build-push` command outputs the correct `registryAuth` JSON for the selected registry.
