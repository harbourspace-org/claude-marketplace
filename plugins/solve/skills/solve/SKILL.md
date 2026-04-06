---
name: solve
description: >
  Solve an issue end-to-end. Accepts a Linear issue URL, an issue ID (e.g. HSDEV-222),
  or a literal text description. Spins up an isolated devkit stack, fixes the problem
  autonomously, verifies it, and creates a GitLab MR.
argument-hint: <linear-url | issue-id | text description>
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, Agent
---

You are solving an issue. The input is: $ARGUMENTS

Adapt these guidelines to the situation — they are not rigid steps.

## Project briefs

**website** — Next.js 16 (Pages Router), React 19, Styled Components + Ant Design 4, Redux Toolkit 2. Connects to laravel API via `API_ENDPOINT_CLIENT`/`API_ENDPOINT_SERVER` env vars (baked at build time). Three Docker containers: `frontend-nginx` (domain gateway), `frontend-react` (Next.js app), `frontend-worker` (sitemap cron). MR branch convention: target latest `release/*` branch (currently `release/v2.10`). Pre-prod: `pre-prod.harbour.space`. **If the fix is purely UI/CSS/layout (no API data needed), the website can run standalone without laravel — just skip the API-dependent pages.**

**laravel** — Laravel 6.18, PHP 7.2, MariaDB + Redis. REST API for the entire platform. Keycloak SSO, Firebase, Google APIs, Stripe payments. Service Layer pattern (`app/Services/`). Default branch: `master`. **If the issue requires real production data locally**, run `php artisan db:restore-from-prod` (see `docs/backup-restore.md`). Requires `DB_RESTORE_ENV=PRE-PROD` in the `.env` and `app.env` set to `pre-production`.

**Cloning decision:** Only clone what you need. A CSS fix on website doesn't need laravel. An API bug doesn't need website. Clone both only if the fix spans both. If unsure, clone all.

## 1 — Understand the issue

Determine the input type and get the issue details:
- **Linear URL** (contains `linear.app/`) → fetch it with WebFetch
- **Issue ID** (e.g. `HSDEV-222`) → look it up via `mcp__claude_ai_Linear__search_issues` or fetch `https://linear.app/harbourspace/issue/<ID>`
- **Literal text** → use it directly. No Linear comment will be posted later. Generate a short slug for the stack name (e.g. `fix-login-redirect`).

## 2 — Spin up the devkit stack

Follow the devkit skill at `${CLAUDE_SKILL_DIR}/../../devkit/skills/devkit/SKILL.md` to create an isolated environment.

**Stack name:** issue ID lowercase (e.g. `hsdev-222`) or the generated slug for text input.

Figure out which projects and branches are needed from the issue context and the project briefs above. If you can't determine:
- **Which projects** → use the briefs to decide. Only clone all as a last resort.
- **Which branch or API target** → ask the user. Don't guess.

If the website points to a remote API instead of local laravel, patch the `.env` accordingly after creation.

Start the stack, wait for health checks. **Follow devkit's Output Management rules** — redirect all heavy output (clone, build, install) to `{workspace}/stacks/<stack-name>/.devkit.log`. Only read the log on failure.

## 3 — Fix, verify, iterate

Work inside `{workspace}/stacks/<stack-name>/` (resolve `{workspace}` from the devkit registry — see Step 2). This is autonomous — don't stop to ask unless genuinely stuck.

**Before starting work**, read the `CLAUDE.md` of each cloned project in the stack for project-specific commands, setup instructions, and documentation pointers.

Fix the issue, then **verify exhaustively** before moving on: run tests, write new tests if needed, check logs, use Chrome MCP for UI issues, run lint/build. If something fails, fix it and verify again.

## 4 — Human review

Once all checks pass, present a summary and hand control to the user. **Do not create the MR until the user approves.** If they request changes, make them, re-verify, and ask again. Loop until approved.

## 5 — Create GitLab MR

For each modified project inside the stack:
- Create a branch with the appropriate conventional-commit prefix and the issue ID
- Commit, push, open MR targeting `test` with `--remove-source-branch`
- Use `glab mr create`

## 6 — Post-MR

- **Linear mode:** comment on the issue with the MR link(s) using `mcp__claude_ai_Linear__save_comment`
- Remind the user the stack is still running (`/complete <stack-name>` to clean up later)

## Rules

- All work happens inside the devkit stack directory, not the original repos
- MR target branch is always `test`
- Commit messages include the issue ID (Linear mode)
- Use specific `git add <file>`, never `git add -A`
- Never push to main/master/develop
- **Production database changes are a last resort.** If after exhausting all other options the only viable fix requires SSH into production to modify the database directly: (1) stop and explain to the developer why no code-level fix is possible, (2) explicitly ask the developer for permission, making clear they must get CTO approval before authorizing, (3) only proceed after the developer confirms CTO approval has been granted. Never SSH into production or run direct database modifications without this two-level authorization chain (developer → CTO).
