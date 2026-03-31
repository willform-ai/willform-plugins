---
name: wf-build-push
description: Build a Docker image and push to GHCR or Docker Hub for Willform deployment
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
user-invocable: true
---

# /wf-build-push -- Build & Push Docker Image

## Goal

Build a Docker image from the current project and push it to GitHub Container Registry (GHCR) or Docker Hub for deployment on Willform Agent.

## Language

After loading config, check `WF_LANGUAGE` (set by `wf_load_config`). Use English if `en` or empty, Korean if `ko`. If not set, ask the user to choose (English/한국어) and save to config.

## Instructions

Follow these steps in order. Stop and report to the user if any step fails.

### Step 0: Load config

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/wf-api.sh" && wf_load_config 2>/dev/null || true
```

This loads `WF_LANGUAGE` for localized output. Auth is not required since this skill uses Docker CLI, not the Willform API.

### Step 1: Select Registry

Ask the user which container registry to use:

- **GHCR (Recommended)** — GitHub Container Registry. Best when your code is on GitHub.
- **Docker Hub** — Docker's default registry. Use if you already have images there.

Store the selection for subsequent steps: `REGISTRY=ghcr` or `REGISTRY=dockerhub`.

### Step 2: Verify Registry Authentication

Verify registry authentication:

**For GHCR**: Check if `gh auth status` succeeds or if a `GITHUB_TOKEN` env var with `write:packages` scope is available. Try `docker login ghcr.io` if needed.

**For Docker Hub**: Check if `docker login` credentials exist by running `docker info 2>/dev/null | grep -q Username`. If not logged in, prompt the user to run `docker login`.

If auth cannot be verified, show the user the authentication options and stop. Do not proceed without registry auth.

### Step 3: Verify Docker is Running

```bash
docker info >/dev/null 2>&1
```

If Docker is not running, tell the user to start Docker Desktop or the Docker daemon.

### Step 4: Detect Project Type

Check for these files in the current working directory to determine project type:

| File                     | Project Type       |
|--------------------------|--------------------|
| `package.json`           | Node.js            |
| `requirements.txt`       | Python (pip)       |
| `pyproject.toml`         | Python (poetry/uv) |
| `Pipfile`                | Python (pipenv)    |
| `go.mod`                 | Go                 |
| `Cargo.toml`             | Rust               |
| `pom.xml`                | Java (Maven)       |
| `build.gradle`           | Java (Gradle)      |
| `build.gradle.kts`       | Java (Gradle KTS)  |
| `Gemfile`                | Ruby               |
| `index.html` (only)      | Static site        |

For Node.js, also check for `pnpm-lock.yaml`, `yarn.lock`, or `package-lock.json` to determine the package manager. Check for `next.config.ts` or `next.config.js` to detect Next.js projects.

If the project type cannot be determined, ask the user.

### Step 5: Handle Dockerfile

**If `Dockerfile` exists**: Ask the user whether to use the existing Dockerfile or generate a new one.

**If `Dockerfile` does not exist**: Generate one based on the detected project type. Adapt the template to match the actual project structure:
- Check the actual build output directory (e.g., `dist`, `build`, `.next`, `out`)
- Check the actual entry point file
- Check the port used in the application code
- Use the correct package manager detected in Step 4

Write the generated Dockerfile and show it to the user for confirmation before building.

### Step 6: Generate .dockerignore

If `.dockerignore` does not exist, create one with sensible defaults for the detected project type. Common entries:

```
.git
.gitignore
.env
.env.*
.vscode
.idea
*.md
LICENSE
docker-compose*.yml
```

Plus language-specific entries (e.g., `node_modules` for Node.js, `__pycache__` for Python, `target` for Rust/Java).

### Step 7: Determine Image Reference

Build the full image reference based on the selected registry.

**For GHCR (`REGISTRY=ghcr`)**:

Detect the GitHub repository owner and name:

```bash
gh repo view --json owner,name -q '"\(.owner.login)/\(.name)"' 2>/dev/null
```

If `gh` is unavailable, parse from git remote:

```bash
git remote get-url origin | sed -E 's|.*github.com[:/]([^/]+)/([^/.]+).*|\1/\2|'
```

Full image reference: `ghcr.io/{owner}/{repo}:{tag}`

**For Docker Hub (`REGISTRY=dockerhub`)**:

Ask the user for their Docker Hub username. Use the current directory name as the default repository name — confirm with the user.

Full image reference: `docker.io/{username}/{repo}:{tag}`

**Tag (both registries)**:

```bash
git rev-parse --short HEAD
```

If not in a git repo, use `latest` as the tag.

**Important**: Normalize the full image reference to lowercase:

```bash
IMAGE_REF=$(echo "${IMAGE_REF}" | tr '[:upper:]' '[:lower:]')
```

Docker Hub requires lowercase image names. Apply this normalization for both registries for consistency.

### Step 8: Build Image

```bash
docker build --platform linux/amd64 -t ${IMAGE_REF} .
```

The `--platform linux/amd64` flag is required because Willform Agent runs on EKS with amd64 nodes. This ensures the image works regardless of the build machine architecture.

If the build fails, show the error output to the user. Common issues:
- Missing build dependencies
- Wrong entry point path
- Build script errors

### Step 9: Push Image

```bash
docker push ${IMAGE_REF}
```

**If push fails (GHCR)**:
- 403: Make the package public in GitHub package settings, or ensure the token has `write:packages` scope

**If push fails (Docker Hub)**:
- 401/403: Re-run auth check, or try `docker login` interactively
- "denied: requested access to the resource is denied": The repository may not exist yet — Docker Hub auto-creates on first push if the user has a valid account. Check the username and repository name.

### Step 10: Verify and Output

Verify the pushed image:

```bash
docker manifest inspect ${IMAGE_REF}
```

Confirm the manifest contains a `linux/amd64` entry.

Then output the result with registry-specific deploy guidance:

**For GHCR**:
```
Image pushed successfully: ghcr.io/{owner}/{repo}:{tag}

Deploy with:
  /wf-deploy  (deploy to Willform Agent)

Image reference (copy this): ghcr.io/{owner}/{repo}:{tag}

registryAuth (for Willform deploy API):
  {
    "server": "ghcr.io",
    "username": "{github_username}",
    "password": "{github_token}"
  }
```

**For Docker Hub**:
```
Image pushed successfully: docker.io/{username}/{repo}:{tag}

Deploy with:
  /wf-deploy  (deploy to Willform Agent)

Image reference (copy this): docker.io/{username}/{repo}:{tag}

registryAuth (for Willform deploy API):
  {
    "server": "https://index.docker.io/v1/",
    "username": "{dockerhub_username}",
    "password": "{dockerhub_token}"
  }
```

Note: The Docker Hub server value `https://index.docker.io/v1/` is the standard format required by Kubernetes imagePullSecrets.

## Error Handling

- If any step fails, stop and report the error clearly. Do not retry the same command.
- If Docker build fails, suggest checking the Dockerfile and build context.
- If push fails with auth errors, re-run the auth check script and show the user options.
