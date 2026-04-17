---
name: solve
description: >
  Solve an issue end-to-end. Accepts a Linear issue URL, an issue ID (e.g. HSDEV-222),
  or a literal text description. Spins up an isolated devkit stack, fixes the problem
  autonomously, verifies it, and creates a GitLab MR. Add "local" to skip devkit
  and work directly in the current project.
argument-hint: <linear-url | issue-id | text description> [local]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, Agent
---

You are solving an issue. The input is: $ARGUMENTS

Adapt these guidelines to the situation — they are not rigid steps.

## Mode detection

Check if the input contains the word **"local"** (case-insensitive). If it does:
- Set **local mode = true** — you will work directly in the current working directory instead of creating a devkit stack.
- Strip "local" from the input before parsing the issue reference.

If "local" is absent → **stack mode** (default, uses devkit as before).

## Project briefs

**website** — Next.js 16 (Pages Router), React 19, Styled Components + Ant Design 4, Redux Toolkit 2. Connects to laravel API via `API_ENDPOINT_CLIENT`/`API_ENDPOINT_SERVER` env vars (baked at build time). Three Docker containers: `frontend-nginx` (domain gateway), `frontend-react` (Next.js app), `frontend-worker` (sitemap cron). MR branch convention: target latest `release/*` branch (currently `release/v2.10`). Pre-prod: `pre-prod.harbour.space`. **If the fix is purely UI/CSS/layout (no API data needed), the website can run standalone without laravel — just skip the API-dependent pages.**

**laravel** — Laravel 6.18, PHP 7.2, MariaDB + Redis. REST API for the entire platform. Keycloak SSO, Firebase, Google APIs, Stripe payments. Service Layer pattern (`app/Services/`). Default branch: `master`. **If the issue requires real production data locally**, run `php artisan db:restore-from-prod` (see `docs/backup-restore.md`). Requires `DB_RESTORE_ENV=PRE-PROD` in the `.env` and `app.env` set to `pre-production`.

**Cloning decision:** Only clone what you need. A CSS fix on website doesn't need laravel. An API bug doesn't need website. Clone both only if the fix spans both. If unsure, clone all.

## 1 — Understand the issue

Determine the input type and get the issue details:
- **Linear URL** (contains `linear.app/`) → fetch it with WebFetch
- **Issue ID** (e.g. `HSDEV-222`) → look it up via `mcp__claude_ai_Linear__search_issues` or fetch `https://linear.app/harbourspace/issue/<ID>`
- **Literal text** → use it directly. No Linear comment will be posted later. Generate a short slug for the stack name (e.g. `fix-login-redirect`).

## 2 — Set up the environment

### Stack mode (default)

Follow the devkit skill at `${CLAUDE_SKILL_DIR}/../../devkit/skills/devkit/SKILL.md` to create an isolated environment.

**Stack name:** issue ID lowercase (e.g. `hsdev-222`) or the generated slug for text input.

Figure out which projects and branches are needed from the issue context and the project briefs above. If you can't determine:
- **Which projects** → use the briefs to decide. Only clone all as a last resort.
- **Which branch or API target** → ask the user. Don't guess.

If the website points to a remote API instead of local laravel, patch the `.env` accordingly after creation.

Start the stack, wait for health checks. **Follow devkit's Output Management rules** — redirect all heavy output (clone, build, install) to `{workspace}/stacks/<stack-name>/.devkit.log`. Only read the log on failure.

### Local mode

Skip devkit entirely. You work directly in the **current working directory** (`$CWD`).

1. Identify which project you're in by checking for known markers (`artisan` → laravel, `next.config.*` → website). If the CWD doesn't match either project, ask the user to `cd` into the correct directory or specify the path.
2. Create a feature branch from the current branch: `git checkout -b <prefix>/<issue-id-or-slug>` (conventional-commit prefix based on the issue type — `fix/`, `feat/`, `chore/`, etc.). If the user is already on a feature branch, ask before switching.
3. **Do not** create, start, or reference any devkit stack. All Docker / environment setup is the user's responsibility in local mode.
4. The working directory for Phase 3 is simply `$CWD`.

## 3 — Fix, verify, iterate

- **Stack mode:** work inside `{workspace}/stacks/<stack-name>/` (resolve `{workspace}` from the devkit registry — see Step 2).
- **Local mode:** work inside `$CWD`.

This is autonomous — don't stop to ask unless genuinely stuck.

**Before starting work**, read the `CLAUDE.md` of the project for project-specific commands, setup instructions, and documentation pointers.

Fix the issue, then **verify exhaustively** before moving on: run tests, write new tests if needed, check logs, use Chrome MCP for UI issues, run lint/build. If something fails, fix it and verify again.

## 4 — Human review

Once all checks pass, present a summary and hand control to the user. **Do not create the MR until the user approves.** If they request changes, make them, re-verify, and ask again. Loop until approved.

## 5 — Create GitLab MR

### Stack mode
For each modified project inside the stack:
- Create a branch with the appropriate conventional-commit prefix and the issue ID
- Commit, push, open MR targeting `test` with `--remove-source-branch`
- Use `glab mr create`

### Local mode
- The feature branch was already created in Phase 2. Commit all changes with `git add <file>` (specific files), then push.
- Open MR targeting `test` with `--remove-source-branch` using `glab mr create`.

## 6 — Post-MR

- **Linear mode:** comment on the issue with the MR link(s) using `mcp__claude_ai_Linear__save_comment`
- **Stack mode only:** remind the user the stack is still running (`/complete <stack-name>` to clean up later)
- **Local mode:** no cleanup needed — the user's local environment is untouched.

## 7 — Update docs

For each repo that was modified, invoke the `update-docs` skill:

- **Stack mode:** use the repo paths inside the stack directory (e.g. `{workspace}/stacks/<stack-name>/website`)
- **Local mode:** use `$CWD`

```
/update-docs <repo-path>
```

Run once per modified repo. This is a best-effort step — if `last_documented_commit` doesn't exist in a repo yet, `update-docs` will use the last 30 commits as scope and create the file automatically. Don't block or fail the overall solve flow if this step encounters an error.

## Rules

- **Stack mode:** all work happens inside the devkit stack directory, not the original repos
- **Local mode:** all work happens in the user's current working directory — never create or reference devkit stacks
- MR target branch is always `test`
- Commit messages include the issue ID (Linear mode)
- Use specific `git add <file>`, never `git add -A`
- Never push to main/master/develop
- **Production database changes are a last resort.** If after exhausting all other options the only viable fix requires SSH into production to modify the database directly: (1) stop and explain to the developer why no code-level fix is possible, (2) explicitly ask the developer for permission, making clear they must get CTO approval before authorizing, (3) only proceed after the developer confirms CTO approval has been granted. Never SSH into production or run direct database modifications without this two-level authorization chain (developer → CTO).
