---
name: docs
description: >
  Manage Harbour.Space documentation in the central GitHub MkDocs repo.
  Triggers when updating docs/ content, publishing project docs to
  docs.harbour.space, or changing docs automation.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
argument-hint: "[project-name or topic]"
---

# Harbour.Space Documentation Management

You manage documentation for the Harbour.Space engineering ecosystem. The human-browsable site is `docs.harbour.space`; the source repo is `harbourspace-org/docs` on GitHub.

## Current Publishing Model

The current source of truth for the published site is the central docs repo:

```text
https://github.com/harbourspace-org/docs
```

Most documentation updates should be made directly in that repo under `docs/<project-or-area>/`, then validated with `mkdocs build --strict`.

Some project repos may keep local `docs/` folders for development-time reference. Those are not automatically published unless that repo has an explicit GitHub Actions sync workflow. Do not assume sync automation or a deploy token exists.

## Repository Layout

Central docs repo:

```text
docs/
  index.md
  <project-or-area>/
    ...
mkdocs.yml
requirements.txt
.github/workflows/validate.yml
```

Project sections should be organized around how humans browse the system. Simple projects may use `overview`, `architecture`, and `setup` pages. Larger greenfield systems may have deeper sections such as `getting-started/`, `architecture/`, `operations/`, `data/`, and `reference/`.

## When To Update Docs

| Change type | Action |
|---|---|
| New endpoint, API, or service | Add or update the relevant project docs page. |
| Architecture or data-flow change | Update architecture docs. |
| Setup or environment change | Update setup/getting-started docs. |
| Deployment, CI, or operations change | Update operations or developer-experience docs. |
| Cross-project behavior | Add or update a central docs page that spans the affected projects. |

## Workflow

1. Locate the published section in `harbourspace-org/docs`.
2. Edit the relevant Markdown and `mkdocs.yml` nav entry together.
3. Run:

```bash
pip install --no-cache-dir -r requirements.txt
mkdocs build --strict
```

4. Commit the docs repo change.

If a project repo also keeps local docs, update those in the same workstream when they are intended to remain the project-local source.

## Writing Guidelines

- Be concrete: include real paths, commands, URLs, env vars, and runbooks.
- Prefer small topic pages over one huge document.
- Keep filenames kebab-case.
- Avoid filler and template sections that do not help the reader.
- Keep navigation aligned with `mkdocs.yml`.
- Run strict MkDocs validation before publishing.

## Optional Automation

Project-repo-to-docs-repo sync is optional and must be configured explicitly. For the current GitHub-era pattern, see `sync-pipeline.md`.
