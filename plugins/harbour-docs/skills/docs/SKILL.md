---
name: docs
description: >
  Manage documentation across Harbour.Space project repos and the central
  MkDocs docs site. Triggers when making changes that should be documented,
  when working with docs/ directories, CLAUDE.md files, or when content
  spans multiple projects. Also invocable manually to review, create, or
  update documentation.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
argument-hint: "[project-name or topic]"
---

# Harbour.Space Documentation Management

You manage documentation across a multi-repo ecosystem. Every project syncs its docs to a central MkDocs site at `docs.harbour.space`. Humans can browse all documentation there.

## How It Works

Each project repo has a CI job that watches for changes to `docs/` and `CLAUDE.md`. When you merge to main, CI automatically syncs those files to the central docs site. You don't need to do anything special — just edit the files in the project repo and merge. The rest is automatic.

The only exception is **cross-project content** that doesn't belong to any single repo. For that, you write directly to the `docs-site` repo (`gitlab.com/harbourspace/docs`).

## Documentation Architecture

There are two kinds of documentation per project, plus the central site:

### 1. `CLAUDE.md` (project root)
- Auto-loaded by Claude Code every session — keep it **concise**
- Serves as the project **overview**: stack, commands, architecture summary, key config, important notes
- Also includes agent-relevant specifics (conventions, gotchas, integration points) written naturally — no "agent-only" sections
- Synced to the docs site as the **Overview** tab
- If content is only useful when working on a specific area, it belongs in `docs/` instead

### 2. `docs/` directory (project root)
- Deep-dive reference for **both agents and humans**
- Agents load these **on-demand** when working on a relevant area of the codebase
- Humans browse them on the MkDocs site
- Standard files:
  - `architecture.md` — detailed architecture, data flow, component relationships
  - `setup.md` — local development setup, prerequisites, environment config
  - Topic-specific files as needed: `api.md`, `graphql.md`, `auth.md`, `state-management.md`, `pipeline.md`, `components.md`, `content-types.md`, `nova.md`, etc.
- File naming: kebab-case, singular topics (e.g. `auth.md` not `authentication.md`)

### 3. Central docs site (`docs-site` repo / `gitlab.com/harbourspace/docs`)
- MkDocs Material site at `docs.harbour.space` — the human-browsable hub for all project docs
- Content arrives automatically via CI sync from project repos (see `sync-pipeline.md`)
- CI sync and deployment take a few minutes after merge
- **Write directly here** only for content that doesn't belong to any single project:
  - Cross-project integration guides
  - High-level architecture overviews spanning multiple services
  - Shared infrastructure documentation
  - Migration guides, onboarding docs

## When to Update Documentation

After making code changes, check if any of these apply:

| Change type | Action |
|---|---|
| New endpoint, API, or service | Add/update `docs/api.md` or relevant topic file |
| Architecture change (new component, changed data flow) | Update `docs/architecture.md` |
| Setup steps changed (new dependency, env var, config) | Update `docs/setup.md` |
| New integration with another service | Update `docs/` in the project, and if it spans projects, add a cross-project doc to docs-site |
| Stack change (framework, major dependency) | Update `CLAUDE.md` overview |
| New commands or scripts | Update `CLAUDE.md` commands section |
| Convention or gotcha discovered | Add to `CLAUDE.md` if always-relevant, or `docs/` if area-specific |

## Read Before You Guess

When diving into an unfamiliar area of a project:

1. Check if `docs/` has a relevant file: `Glob docs/*.md` in the project root
2. Read it before making assumptions about architecture or conventions
3. If no docs exist for the area you're working in, consider creating them after you understand the code

## Writing Guidelines

- **Write naturally for the project** — there's no rigid template. Adapt sections to what the project actually needs
- **CLAUDE.md should read as a project overview** — what this is, why it exists, how it fits in the ecosystem, then practical details (stack, commands, architecture, config, deployment). Not a dry spec sheet
- **Be concrete** — include actual file paths, command examples, config snippets
- **No filler** — skip "In this document we will..." preambles
- **Plain markdown** — tables, code blocks with language tags, standard headers. No need for admonitions or fancy MkDocs features
- **Keep CLAUDE.md lean** — if you're adding more than a few lines about a specific area, it probably belongs in `docs/`
- **Don't duplicate** — CLAUDE.md gives the overview, docs/ goes deep. Don't repeat the same content in both

## Scaffolding a New Project

When a new project is added to the ecosystem:

1. Create `CLAUDE.md` at the project root with: stack, commands, architecture summary, key config
2. Create `docs/` with at minimum `architecture.md` and `setup.md`
3. Add the `sync-docs` CI stage to `.gitlab-ci.yml` (see `sync-pipeline.md`)
4. Add a nav entry in `docs-site/mkdocs.yml` under the appropriate category (Backends, Frontends, Infrastructure, or Analytics)

## Reference

For CI setup details (sync job template, deploy token, mkdocs.yml nav format), read on-demand:
- `${CLAUDE_SKILL_DIR}/sync-pipeline.md`
