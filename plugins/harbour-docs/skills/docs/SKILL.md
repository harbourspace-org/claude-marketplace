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

You manage documentation across a multi-repo ecosystem. Every project syncs its docs to a central MkDocs site at `mkdocs.harbour.space`.

## Documentation Architecture

There are two kinds of documentation per project, plus a central site:

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
- MkDocs Material site at `mkdocs.harbour.space`
- Content arrives via CI sync from project repos (see `sync-pipeline.md`)
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

Follow these when writing or updating documentation:

- **Be concrete** — include actual file paths, command examples, config snippets
- **No filler** — skip "In this document we will..." preambles
- **MkDocs Material compatible** — use admonitions, tabbed content, code fences with language tags (see `conventions.md` in this skill directory for syntax reference)
- **Keep CLAUDE.md lean** — if you're adding more than a few lines, it probably belongs in `docs/`
- **Don't duplicate** — CLAUDE.md gives the overview, docs/ goes deep. Don't repeat the same content in both

## Scaffolding a New Project

When a new project is added to the ecosystem:

1. Create `CLAUDE.md` at the project root with: stack, commands, architecture summary, key config
2. Create `docs/` with at minimum `architecture.md` and `setup.md`
3. Add the `sync-docs` CI stage to `.gitlab-ci.yml` (see `sync-pipeline.md`)
4. Add a nav entry in `docs-site/mkdocs.yml` under the appropriate category (Backends, Frontends, Infrastructure, or Analytics)

## Reference Files

For detailed syntax and templates, read these on-demand:
- `${CLAUDE_SKILL_DIR}/conventions.md` — MkDocs markdown syntax, section templates, nav format
- `${CLAUDE_SKILL_DIR}/sync-pipeline.md` — CI sync job template, deploy token setup, mkdocs.yml nav format
