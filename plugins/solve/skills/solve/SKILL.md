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

Follow these steps unless the user implies otherwise — this isn't hardcoded behavior. Adapt to the user's intent.

## Step 0 — Determine input mode

Inspect `$ARGUMENTS` to determine the input type:

- **Linear URL** — if the input contains `linear.app/` or starts with `https://`. Proceed to **Step 1A**.
- **Issue ID** — if the input matches a pattern like `HSDEV-222`, `hsdev-222`, `HSWEB-55`, etc. (1-5 uppercase/lowercase letters, a hyphen, then digits). Proceed to **Step 1C**.
- **Literal text** — anything else is a freeform text description of the problem. Proceed to **Step 1B**.

## Step 1A — Fetch Linear issue from URL

Use WebFetch to load the Linear issue URL: $ARGUMENTS

Extract:
- Issue ID (e.g. HSDEV-222)
- Title
- Description / body
- Any linked resources or reproduction steps
- **Branch hints** — look for explicit mentions of a branch name, source branch, or base branch
- **Project hints** — determine which projects are affected (laravel, website, or both)
- **Server/environment hints** — if the issue involves the website, look for mentions of which API server or environment to point to (e.g. pre-production, production, a specific URL)

Then continue to **Step 2**.

## Step 1B — Parse literal text input

The user provided a text description instead of a Linear issue or ID.

From the text, extract what you can:
- **Problem description** — what needs to be fixed or built
- **Project hints** — any mention of laravel, website, frontend, backend, API, UI, etc.
- **Branch hints** — any mention of a branch name
- **Server/environment hints** — any mention of which environment to target

Since there is no Linear issue:
- **Issue ID** — there is none. Generate a stack name from the text: take the first 3-4 meaningful words, lowercase, joined by hyphens (e.g. `fix-login-redirect`, `add-export-button`). Max 30 characters.
- **No Linear comment** will be posted (skip Step 6).
- **MR description** will reference the original text description instead of a Linear URL.

Then continue to **Step 2**.

## Step 1C — Look up Linear issue by ID

The user provided an issue ID directly (e.g. `HSDEV-222`). Normalize it to uppercase.

Use the `mcp__claude_ai_Linear__search_issues` tool to find the issue by its ID. If no MCP tool is available, construct the Linear URL from the ID and fetch it:

```
https://linear.app/harbourspace/issue/<ISSUE-ID>
```

Once you have the issue, extract the same fields as Step 1A:
- Issue ID, Title, Description / body
- Branch hints, Project hints, Server/environment hints

Then continue to **Step 2**.

Then continue to **Step 2**.

## Step 2 — Resolve environment details

You need three pieces of information before creating the devkit stack:

1. **Affected projects** — which projects need to be cloned and modified (laravel, website, or both)
2. **Branch per project** — what branch to check out for each affected project
3. **API target** (website only) — if the website is involved but laravel is NOT being modified, which remote API server should it point to

### How to resolve

First, check the issue/problem description from Step 1A or 1B for explicit answers.

If any detail is missing from the issue, try to infer it from the CLAUDE.md files of each project in the codebase. The CLAUDE.md files contain information about branch strategies, environments, and deployment targets. Read them:

```bash
# Check for CLAUDE.md in known project locations
cat ~/Documents/HSCode/work/laravel/CLAUDE.md 2>/dev/null
cat ~/Documents/HSCode/work/website/CLAUDE.md 2>/dev/null
```

**Inference rules:**
- If the issue mentions a specific file path or code pattern, grep the codebase to determine which project(s) it belongs to
- If the issue is clearly a backend bug (API, database, queue, etc.) → laravel only
- If the issue is clearly a frontend/UI bug → website only (but you still need to know the API target)
- If the issue spans both → both projects
- For branches: if no branch is mentioned, use the project's default branch from the devkit registry (laravel: `master`, website: `main`)
- For API target when website-only: if the issue doesn't mention a server and the CLAUDE.md doesn't clarify, you MUST ask

### If you can't determine which projects are affected — CLONE ALL

If after reading the issue and the CLAUDE.md files you still can't confidently determine which projects need changes, **clone all projects** (this is devkit's default behaviour). Do not block on this question — it's better to have all projects available and not need them than to be missing one mid-fix.

### If you can't determine branch or API target — ASK THE USER

Use AskUserQuestion to ask specifically what you need. Examples:

- *"The issue doesn't specify which branch to base this on for `laravel`. Should I use `master` or a specific branch?"*
- *"This looks like a website-only issue. Which API server should the website point to? (e.g. `https://pre-prod.harbour.space`, local laravel, etc.)"*

Do NOT proceed without a resolved branch and API target (when applicable).

## Step 3 — Create devkit stack

Use the devkit skill to spin up an isolated development environment for this issue.

**Stack name:**
- **Linear mode:** Use the issue ID in lowercase (e.g. `hsdev-222` for issue HSDEV-222).
- **Text mode:** Use the generated slug from Step 1B (e.g. `fix-login-redirect`).

Build the devkit create command based on what you resolved in Step 2:

```bash
# Example: both projects, laravel on a feature branch, website on main
devkit create hsdev-222 --branches laravel:feature/some-branch,website:main

# Example: laravel only
devkit create hsdev-222 --projects laravel --branches laravel:master

# Example: website only (laravel still needed for local API)
devkit create hsdev-222 --branches laravel:master,website:main
```

**Important:** Invoke the devkit skill commands by running them as described in the devkit SKILL.md — read the devkit registry.json, run pre-flight checks, and execute the create flow. The devkit skill files are located at:
- `${CLAUDE_SKILL_DIR}/../../devkit/skills/devkit/SKILL.md`
- `${CLAUDE_SKILL_DIR}/../../devkit/skills/devkit/registry.json`

If the website is involved but laravel is NOT being modified and the user specified a remote API target, patch the website `.env` after creation to point to that remote server instead of the local laravel instance:

```bash
# Override API endpoints in the website .env to point to remote server
STACK_DIR=~/Documents/HSCode/work/stacks/hsdev-222/website
sed -i '' "s|API_ENDPOINT_CLIENT=.*|API_ENDPOINT_CLIENT=${REMOTE_API_URL}|" "$STACK_DIR/.env"
sed -i '' "s|API_ENDPOINT_SERVER=.*|API_ENDPOINT_SERVER=${REMOTE_API_URL}|" "$STACK_DIR/.env"
sed -i '' "s|HSAJAX_ENDPOINT_CLIENT=.*|HSAJAX_ENDPOINT_CLIENT=${REMOTE_API_URL}|" "$STACK_DIR/.env"
sed -i '' "s|HSAJAX_ENDPOINT_SERVER=.*|HSAJAX_ENDPOINT_SERVER=${REMOTE_API_URL}|" "$STACK_DIR/.env"
```

After the stack is created, start it:
```
devkit up hsdev-222
```

Wait for health checks to pass before proceeding.

## Step 4 — Fix, verify, and iterate

Work inside the devkit stack directory: `~/Documents/HSCode/work/stacks/<issue-id>/`

This step is **autonomous**. Fix the issue and verify the fix yourself — do not stop to ask for approval unless you are genuinely stuck.

### 4a — Understand

- Read the issue description carefully
- Search the codebase for relevant files (Grep, Glob, Read) within the stack directory
- Identify the root cause or the right place to add the feature

### 4b — Implement

- Make the targeted changes
- Keep changes minimal and focused — do not refactor unrelated code

### 4c — Verify exhaustively

You MUST verify that the fix actually works. Use every tool at your disposal:

1. **Run existing tests** — execute the project's test suite and ensure nothing breaks:
   ```bash
   # Laravel
   docker exec devkit-<instance>-laravel-php7 php artisan test
   # Website
   docker exec devkit-<instance>-frontend-react npm test
   ```

2. **Write new tests** — if the bug or feature doesn't have test coverage, write tests that prove the fix works and would have caught the original issue.

3. **Check logs** — read container logs for errors or warnings:
   ```bash
   devkit logs <instance> <project>
   ```

4. **Use Chrome MCP** — if the issue is visual or involves UI behavior, use the Chrome MCP tools to:
   - Navigate to the affected page
   - Verify the UI renders correctly
   - Interact with the page to confirm the fix
   - Take screenshots if useful

5. **Run lint/build** — ensure the code compiles and passes linting:
   ```bash
   # Laravel
   docker exec devkit-<instance>-laravel-php7 ./vendor/bin/phpstan analyse
   # Website
   docker exec devkit-<instance>-frontend-react npm run build
   ```

6. **Test edge cases** — think about what could still go wrong and test those scenarios too.

### 4d — Iterate

If verification reveals problems, fix them and verify again. Repeat until you are confident the issue is fully resolved.

### 4e — Human review (MANDATORY before MR)

Once you believe the fix is complete and all your automated checks pass, **stop and hand control to the user for review**.

Present a summary of what you changed and remind the user:

> **Your review is required before I create the MR.** It's your responsibility to verify everything works correctly. Please review the changes, test them yourself if needed, and let me know:
> - **"approved"** / **"looks good"** / **"go ahead"** → I'll create the MR
> - Or tell me what needs to change → I'll fix it

**Do NOT create the MR until the user explicitly approves.**

If the user requests changes:
1. Make the changes they ask for
2. Re-run verification (tests, build, logs, browser — whatever applies)
3. Present the updated summary
4. Ask for approval again

This is a collaborative loop — keep iterating with the user until they are satisfied. There is no limit on how many rounds this can take.

## Step 5 — Create a GitLab MR

### Determine the branch prefix

Based on the nature of the issue, choose the correct conventional-commit prefix:

| Issue type | Branch prefix | Commit prefix |
|---|---|---|
| Bug / broken behaviour | `fix/` | `fix` |
| New feature / enhancement | `feat/` | `feat` |
| Refactor (no behaviour change) | `refactor/` | `refactor` |
| Chore / dependency / config | `chore/` | `chore` |
| Docs | `docs/` | `docs` |
| Performance | `perf/` | `perf` |
| Tests | `test/` | `test` |

Use the issue title and description to determine the right type. When in doubt, prefer `fix` for bugs and `feat` for everything else.

### Branch & commit

For each project that was modified, `cd` into its stack directory and:

```bash
cd ~/Documents/HSCode/work/stacks/hsdev-222/<project>

git checkout -b <prefix>/ISSUE-ID-short-description
```

Stage and commit:
```bash
git add <specific files>
# Linear mode:
git commit -m "<prefix>(ISSUE-ID): short description matching the Linear issue title"
# Text mode (no issue ID):
git commit -m "<prefix>: short description derived from the problem text"
```

Push:
```bash
git push -u origin HEAD
```

### Open the MR

For each project that has changes:

```bash
cd ~/Documents/HSCode/work/stacks/hsdev-222/<project>

### Linear mode:
glab mr create \
  --title "<prefix>(ISSUE-ID): <issue title>" \
  --description "$(cat <<'EOF'
## Summary

Closes [ISSUE-ID]($ARGUMENTS)

<bullet points describing what changed and why>

## Test plan
- [ ] Verify the reported behaviour is resolved
- [ ] Smoke test affected pages/flows
EOF
)" \
  --target-branch test \
  --remove-source-branch

### Text mode (no Linear issue):
glab mr create \
  --title "<prefix>: <short description>" \
  --description "$(cat <<'EOF'
## Summary

<bullet points describing what changed and why>

## Context

Original request:
> <the literal text the user provided>

## Test plan
- [ ] Verify the reported behaviour is resolved
- [ ] Smoke test affected pages/flows
EOF
)" \
  --target-branch test \
  --remove-source-branch
```

Capture the MR URL(s) from the command output.

## Step 6 — Comment on the Linear issue (Linear mode only)

**Skip this step entirely if the input was literal text (Step 1B).**

After the MR(s) are created, post a comment on the Linear issue using the `mcp__claude_ai_Linear__save_comment` tool.

The issue ID was extracted in Step 1A (e.g. `HSDEV-222`). Use it to look up the issue and post the comment.

Comment body (replace `<MR_URL>` with the actual URL(s) from Step 5):

```
MR: <MR_URL>

By Claude 🤖
```

If multiple MRs were created (one per project), list them all.

Confirm to the user that the comment was posted, and return the MR URL(s) and the Linear issue URL.

## Step 7 — Cleanup reminder

Remind the user that the devkit stack `hsdev-222` is still running. They can:
- `devkit down hsdev-222` — stop the containers
- `devkit destroy hsdev-222` — remove everything after the MR is merged

## Important rules
- **Autonomous mode** — do not pause for user approval during implementation and verification. Fix it, verify it, iterate until it works. Only ask the user if you are genuinely stuck.
- Always read relevant code before editing — understand first, then change
- Always use specific `git add <file>` rather than `git add -A`
- **Verify exhaustively** — never create an MR without confirming the fix works (tests, logs, browser, build)
- Branch prefix and commit type must match the nature of the issue (fix/feat/chore/refactor/docs/perf/test)
- MR target branch is always `test`
- Commit message must include the Linear issue ID
- Do not push to main/master/develop directly
- All work happens inside the devkit stack directory, NOT in the original project repos
- If you can't determine the branch, affected projects, or API target — ASK, don't guess
- Stack name is always the issue ID in lowercase (e.g. `hsdev-222`)
