---
name: solve
description: Solve a Linear issue end-to-end. Fetches the issue, plans a fix, implements it, and creates a GitLab MR. Use when given a Linear issue URL to resolve.
argument-hint: <linear-issue-url>
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, Agent
---

You are solving a Linear issue. The issue URL is: $ARGUMENTS

Follow these steps exactly:

## Step 1 — Fetch the issue

Use WebFetch to load the Linear issue URL: $ARGUMENTS

Extract:
- Issue ID (e.g. HSDEV-141)
- Title
- Description / body
- Any linked resources or reproduction steps

## Step 2 — Plan

Think through the fix before touching code:
- Understand what the bug/feature is from the issue description
- Search the codebase for relevant files (use Grep, Glob, Read)
- Identify the root cause or the right place to add the feature
- Write a short, clear plan: what files change and why

Present the plan to the user and wait for approval before proceeding.

## Step 3 — Implement

- Make the targeted changes described in the plan
- Keep changes minimal and focused — do not refactor unrelated code
- Run any relevant checks if possible (lint, build, tests)

## Step 4 — Create a GitLab MR

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

Check current branch:
```bash
git rev-parse --abbrev-ref HEAD
```

If on main/master/release/develop branch, create a new branch:
```bash
git checkout -b <prefix>/ISSUE-ID-short-description
```

Stage and commit:
```bash
git add <specific files>
git commit -m "<prefix>(ISSUE-ID): short description matching the Linear issue title"
```

Push:
```bash
git push -u origin HEAD
```

### Open the MR

```bash
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
  --target-branch develop \
  --remove-source-branch
```

Capture the MR URL from the command output.

## Step 5 — Comment on the Linear issue

After the MR is created, post a comment on the Linear issue using the `mcp__claude_ai_Linear__save_comment` tool.

The issue ID was extracted in Step 1 (e.g. `HSDEV-141`). Use it to look up the issue and post the comment.

Comment body (replace `<MR_URL>` with the actual URL from Step 4):

```
MR: <MR_URL>

By Claude 🤖
```

Confirm to the user that the comment was posted, and return both the MR URL and the Linear issue URL.

## Important rules
- Never skip the planning step — always read relevant code before editing
- Always use specific `git add <file>` rather than `git add -A`
- Branch prefix and commit type must match the nature of the issue (fix/feat/chore/refactor/docs/perf/test)
- Branch from the current HEAD (do not branch off main/master directly)
- MR target branch is always `develop`
- Commit message must include the Linear issue ID
- Do not push to main/master/develop directly
