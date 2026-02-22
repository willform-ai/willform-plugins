---
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
description: Build a Docker image and push to GHCR for Willform deployment
user-invocable: true
---

# Build & Push Docker Image to GHCR

Build a Docker image from the current project and push it to GitHub Container Registry for deployment on Willform Agent.

## Instructions

Follow these steps in order. Stop and report to the user if any step fails.

### Step 1: Verify GHCR Authentication

Run the auth check script:

```bash
bash skills/dockerfile-build/scripts/ghcr-auth-check.sh
```

If the script path is not found, try the plugin root:
```bash
bash "${PLUGIN_DIR:-skills/dockerfile-build}/scripts/ghcr-auth-check.sh"
```

If the script exits non-zero, show the user the authentication options from the output and stop. Do not proceed without GHCR auth.

### Step 2: Verify Docker is Running

```bash
docker info >/dev/null 2>&1
```

If Docker is not running, tell the user to start Docker Desktop or the Docker daemon.

### Step 3: Detect Project Type

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

### Step 4: Handle Dockerfile

**If `Dockerfile` exists**: Ask the user whether to use the existing Dockerfile or generate a new one.

**If `Dockerfile` does not exist**: Generate one using the appropriate template from the skill reference at `skills/dockerfile-build/references/dockerfile-patterns.md`. Adapt the template to match the actual project structure:
- Check the actual build output directory (e.g., `dist`, `build`, `.next`, `out`)
- Check the actual entry point file
- Check the port used in the application code
- Use the correct package manager detected in Step 3

Write the generated Dockerfile and show it to the user for confirmation before building.

### Step 5: Generate .dockerignore

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

### Step 6: Determine Image Reference

Detect the GitHub repository owner and name:

```bash
gh repo view --json owner,name -q '"\(.owner.login)/\(.name)"' 2>/dev/null
```

If `gh` is unavailable, parse from git remote:

```bash
git remote get-url origin | sed -E 's|.*github.com[:/]([^/]+)/([^/.]+).*|\1/\2|'
```

Get the image tag from the current git SHA:

```bash
git rev-parse --short HEAD
```

If not in a git repo, use `latest` as the tag.

The full image reference is: `ghcr.io/{owner}/{repo}:{tag}`

### Step 7: Build Image

```bash
docker build --platform linux/amd64 -t ghcr.io/{owner}/{repo}:{tag} .
```

The `--platform linux/amd64` flag is required because Willform Agent runs on EKS with amd64 nodes. This ensures the image works regardless of the build machine architecture.

If the build fails, show the error output to the user. Common issues:
- Missing build dependencies
- Wrong entry point path
- Build script errors

### Step 8: Push Image

```bash
docker push ghcr.io/{owner}/{repo}:{tag}
```

If push fails with 403, the user likely needs to:
- Make the package public in GitHub package settings
- Or ensure their token has `write:packages` scope

### Step 9: Verify and Output

Verify the pushed image:

```bash
docker manifest inspect ghcr.io/{owner}/{repo}:{tag}
```

Confirm the manifest contains a `linux/amd64` entry.

Then output the result:

```
Image pushed successfully: ghcr.io/{owner}/{repo}:{tag}

Deploy with:
  /wf-deploy-openclaw  (for OpenClaw agents)
  Or use the Willform deploy skill for custom deployments

Image reference (copy this): ghcr.io/{owner}/{repo}:{tag}
```

## Error Handling

- If any step fails, stop and report the error clearly. Do not retry the same command.
- If Docker build fails, suggest checking the Dockerfile and build context.
- If push fails with auth errors, re-run the auth check script and show the user options.
