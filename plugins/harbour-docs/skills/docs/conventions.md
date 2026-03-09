# Documentation Conventions

Reference for writing MkDocs Material-compatible documentation across Harbour.Space projects.

## File Naming

- Kebab-case: `state-management.md`, `content-types.md`
- Singular topics: `api.md` not `apis.md`, `auth.md` not `authentication.md`
- Standard files every project should have:
  - `architecture.md` — system design, data flow, component relationships
  - `setup.md` — local dev setup, prerequisites, env config

## CLAUDE.md Structure

Keep it concise. Typical sections:

```markdown
# CLAUDE.md — {project-name}

One-line description of what this project does.

## Stack
- **Framework** version — role
- **Database** — role
- List key dependencies

## Commands
\```bash
npm install
npm run dev           # what this does
npm run build         # what this does
npm run test          # what this does
\```

## Architecture
\```
src/
  routes/         # Brief explanation
  services/       # Brief explanation
  models/         # Brief explanation
\```

## Key Config Details
Env vars, important config files, non-obvious settings.

## Important Notes
- Conventions, gotchas, things that trip people up
- Integration points with other services
```

## docs/ File Structure

### architecture.md

```markdown
# Architecture

## Overview
Brief description of the system's purpose and high-level design.

## System Diagram
\```
[Service A] → [Service B] → [Database]
                ↓
            [Queue] → [Worker]
\```

## Components

### Component Name
What it does, where it lives, how it connects to other components.

## Data Flow
Step-by-step description of key data flows (e.g., request lifecycle, event processing).

## Database Schema
Key tables/collections and their relationships. Not a full dump — focus on what matters.
```

### setup.md

```markdown
# Local Development Setup

## Prerequisites
- Node 20+ / PHP 8.2+ / Python 3.12+
- Docker & Docker Compose
- Access to X, Y, Z

## Quick Start
\```bash
git clone ...
cp .env.example .env.local
# fill in required values
npm install
npm run dev
\```

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | Yes | PostgreSQL connection string |
| `API_KEY` | Yes | Third-party API key |

## Common Issues

### Issue description
Solution or workaround.
```

## MkDocs Material Markdown Syntax

### Admonitions

```markdown
!!! note "Optional title"
    Content inside the admonition.

!!! warning
    Important warning content.

!!! tip "Pro tip"
    Helpful hint.

??? info "Collapsible section (closed by default)"
    Hidden content revealed on click.

???+ info "Collapsible section (open by default)"
    Visible content that can be collapsed.
```

Available types: `note`, `abstract`, `info`, `tip`, `success`, `question`, `warning`, `failure`, `danger`, `bug`, `example`, `quote`

### Tabbed Content

```markdown
=== "Tab 1"

    Content for tab 1.

=== "Tab 2"

    Content for tab 2.
```

### Code Blocks

Always specify the language:

```markdown
\```python
def hello():
    print("hello")
\```

\```bash
npm run dev
\```

\```yaml
key: value
\```
```

### Tables

```markdown
| Column 1 | Column 2 | Column 3 |
|---|---|---|
| data | data | data |
```

## mkdocs.yml Navigation Entry Format

When adding a new project to the docs site nav:

```yaml
nav:
  - Backends:
    - project-name:
      - Overview: project-name/CLAUDE.md
      - Architecture: project-name/architecture.md
      - Setup: project-name/setup.md
      # Add topic-specific pages as needed:
      - API Reference: project-name/api.md
```

Categories: **Backends**, **Frontends**, **Infrastructure**, **Analytics**

The project directory name under `docs/` must match `CI_PROJECT_NAME` from GitLab (the repo slug) for CI sync to work correctly.
