# CI/CD Docs Sync Pipeline

How documentation flows from project repos to the central MkDocs site.

## How It Works

```
Project repo (push to main/master/release)
    ↓ CI detects changes to docs/** or CLAUDE.md
    ↓ Clones docs-site repo (gitlab.com/harbourspace/docs)
    ↓ Copies docs/ and CLAUDE.md → docs-site/docs/{project-name}/
    ↓ Commits with [skip ci] and pushes
    ↓
docs-site repo receives commit
    ↓ CI runs: mkdocs build --strict (validates all docs)
    ↓ Dokploy rebuilds and deploys Docker container
    ↓
Live at mkdocs.harbour.space (behind Keycloak SSO)
```

## Adding Sync to a New Project

### 1. Add the CI stage

Add `sync-docs` to your `.gitlab-ci.yml` stages list and append this job:

```yaml
stages:
  # ... existing stages ...
  - sync-docs

sync-docs:
  stage: sync-docs
  image: alpine:latest
  rules:
    - changes:
        - docs/**
        - CLAUDE.md
      when: on_success
    - when: never
  script:
    - |
      apk add --no-cache git
      git clone https://gitlab-ci-token:${DOCS_DEPLOY_TOKEN}@gitlab.com/harbourspace/docs.git /tmp/docs-repo
      mkdir -p /tmp/docs-repo/docs/${CI_PROJECT_NAME}
      cp -r docs/. /tmp/docs-repo/docs/${CI_PROJECT_NAME}/
      cp CLAUDE.md /tmp/docs-repo/docs/${CI_PROJECT_NAME}/CLAUDE.md
      cd /tmp/docs-repo
      git config user.email "ci@harbour.space"
      git config user.name "CI Bot"
      git add .
      git diff --cached --quiet || git commit -m "docs: sync ${CI_PROJECT_NAME} [skip ci]"
      git push
  tags:
    - dev
```

### 2. Set up the deploy token

The `DOCS_DEPLOY_TOKEN` CI/CD variable must be configured in the project's GitLab settings (Settings → CI/CD → Variables). This token needs write access to `gitlab.com/harbourspace/docs`.

If the variable is already set at the group level (`harbourspace`), it will be inherited automatically.

### 3. Add nav entry to docs-site

Edit `docs-site/mkdocs.yml` and add the project under the appropriate category:

```yaml
nav:
  - Backends:  # or Frontends, Infrastructure, Analytics
    # ... existing projects ...
    - your-project-name:
      - Overview: your-project-name/CLAUDE.md
      - Architecture: your-project-name/architecture.md
      - Setup: your-project-name/setup.md
```

The directory name must match the GitLab project slug (`CI_PROJECT_NAME`).

## Important Details

- **`[skip ci]`** in the commit message prevents the docs-site CI from triggering its own sync (avoids infinite loops)
- **`mkdocs build --strict`** on the docs-site catches broken links and missing files — if a nav entry references a file that doesn't exist, the build fails
- **Block scalar (`- |`)** is used in the script because `git commit -m "docs: sync ..."` contains a colon that YAML would otherwise parse as a key-value separator
- The sync only runs when `docs/**` or `CLAUDE.md` actually change — other code changes don't trigger it

## docs-site CI Pipeline

The docs-site repo (`gitlab.com/harbourspace/docs`) has a minimal CI:

```yaml
stages:
  - validate

validate-docs:
  stage: validate
  image: python:3.12-slim
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  script:
    - pip install --no-cache-dir -r requirements.txt
    - mkdocs build --strict
  artifacts:
    paths:
      - site/
    expire_in: 1 hour
```

Deployment is handled by Dokploy, which watches the repo and rebuilds the Docker container on push.
