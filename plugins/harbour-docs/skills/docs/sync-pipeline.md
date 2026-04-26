# GitHub Docs Sync Pipeline

How optional project-repo docs sync works in the GitHub-era Harbour.Space setup.

## Current Default

The central docs repo is the publishing source:

```text
https://github.com/harbourspace-org/docs
```

The docs repo validates on pushes to `main` with:

```yaml
name: validate

on:
  push:
    branches:
      - main

jobs:
  validate-docs:
    runs-on: ubuntu-latest
    container: python:3.12-slim
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: pip install --no-cache-dir -r requirements.txt
      - name: Build docs
        run: mkdocs build --strict
      - uses: actions/upload-artifact@v4
        with:
          name: site
          path: site/
          retention-days: 1
```

Most teams should publish by committing directly to `harbourspace-org/docs`.

## Optional Project Repo Sync

Use this only when a project deliberately keeps `docs/` as its local source of truth and wants changes copied automatically into the central docs repo.

### Required GitHub Secret

Add a fine-grained GitHub PAT to the project repo as:

```text
DOCS_DEPLOY_TOKEN
```

Minimum permission for direct sync commits:

```text
Repository: harbourspace-org/docs
Contents: Read and write
```

If the workflow opens pull requests instead of pushing directly, also grant:

```text
Pull requests: Read and write
```

### Example Direct Sync Workflow

```yaml
name: Sync docs

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - '.github/workflows/sync-docs.yml'
  workflow_dispatch:

concurrency:
  group: sync-docs-${{ github.ref }}
  cancel-in-progress: false

permissions:
  contents: read

jobs:
  sync-docs:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    env:
      DOCS_REPO: harbourspace-org/docs
      DOCS_BRANCH: main
      DOCS_TARGET_DIR: docs/my-project
    steps:
      - name: Checkout project
        uses: actions/checkout@v4
        with:
          path: project

      - name: Checkout docs
        uses: actions/checkout@v4
        with:
          repository: ${{ env.DOCS_REPO }}
          ref: ${{ env.DOCS_BRANCH }}
          token: ${{ secrets.DOCS_DEPLOY_TOKEN }}
          path: docs-site

      - name: Sync docs
        run: |
          mkdir -p "docs-site/${DOCS_TARGET_DIR}"
          rsync -a --delete project/docs/ "docs-site/${DOCS_TARGET_DIR}/"

      - name: Commit and push
        working-directory: docs-site
        run: |
          git config user.email "ci@harbour.space"
          git config user.name "CI Bot"
          git add "${DOCS_TARGET_DIR}"
          if git diff --cached --quiet; then
            echo "No docs changes to sync."
            exit 0
          fi
          git commit -m "docs: sync my-project"
          git push origin "HEAD:${DOCS_BRANCH}"
```

## Important Details

- Do not assume `DOCS_DEPLOY_TOKEN` exists; it must be created intentionally.
- Keep `DOCS_TARGET_DIR` stable so old pages are removed when project docs are deleted.
- Add or update the central `mkdocs.yml` nav entry when introducing a new section.
- Always run `mkdocs build --strict` in the docs repo before considering the change publish-ready.
