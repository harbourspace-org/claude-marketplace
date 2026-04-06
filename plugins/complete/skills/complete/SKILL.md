---
name: complete
description: >
  Post-merge cleanup for issues solved with /solve. Verifies the MR is merged
  and pipelines passed, then tears down the devkit stack, deletes CI/CD pipelines
  if created, removes webhooks, and cleans up all issue-specific resources.
  Use after a /solve issue has been merged and deployed.
argument-hint: <issue-id or stack-name>
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, WebFetch, Agent
---

You are performing post-merge cleanup for an issue that was solved with `/solve`. The argument is: $ARGUMENTS

This skill is the counterpart to `/solve`. After the MR has been merged and CI/CD pipelines have passed, the user invokes `/complete` to tear down everything that `/solve` created.

**First**, resolve `{workspace}` by reading the devkit registry at `${CLAUDE_SKILL_DIR}/../../devkit/skills/devkit/registry.json`. If `workspace` is `"auto"`, use your primary working directory (the directory where this Claude Code session was opened). All paths below use `{workspace}`.

## Step 1 — Identify the stack

The argument can be:
- A **stack name / issue ID** (e.g. `hsdev-222`, `HSDEV-222`) — normalize to lowercase
- A **Linear issue URL** — extract the issue ID and normalize to lowercase

Determine the stack name (always lowercase, e.g. `hsdev-222`).

Verify the stack exists:
```bash
cat {workspace}/stacks/.devkit-instances.json 2>/dev/null
```

If the stack doesn't exist in the instances file, check if the directory exists:
```bash
ls {workspace}/stacks/<stack-name>/ 2>/dev/null
```

If neither exists, inform the user that no stack was found for that issue and stop.

## Step 2 — Verify MR is merged and pipeline passed

Before tearing anything down, confirm that the work is actually done.

For each project in the stack, check the MR status:

```bash
cd {workspace}/stacks/<stack-name>/<project>
# Find MRs from branches in this repo
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
glab mr list --source-branch="$BRANCH" --state=merged 2>/dev/null
glab mr list --source-branch="$BRANCH" --state=opened 2>/dev/null
```

**Decision logic:**

| MR state | Pipeline status | Action |
|---|---|---|
| Merged | Passed | Proceed with cleanup |
| Merged | Still running | Warn user, ask if they want to wait or proceed anyway |
| Merged | Failed | Warn user — pipeline failed. Ask if they still want to clean up |
| Open (not merged) | Any | **Stop.** Tell the user the MR is not merged yet. Do NOT clean up. |
| No MR found | — | Warn user, ask if they want to clean up the stack anyway (may be a manual test stack) |

If the MR is open, tell the user:
> *"The MR for `<project>` on branch `<branch>` is still open (not merged). Cannot clean up until it's merged. Merge it first, then run `/complete` again."*

## Step 3 — Verify pipeline status

For merged MRs, check that the target branch pipeline passed:

```bash
cd {workspace}/stacks/<stack-name>/<project>
# Get the pipeline status for the MR
glab mr view --comments 2>/dev/null | head -50
# Or check pipeline directly
glab ci status 2>/dev/null
```

If the pipeline is still running, inform the user and ask whether to wait or proceed.

## Step 4 — Destroy the devkit stack

Use the devkit skill to tear down the stack completely. Follow the devkit SKILL.md destroy flow:

The devkit skill files are located at:
- `${CLAUDE_SKILL_DIR}/../../devkit/skills/devkit/SKILL.md`
- `${CLAUDE_SKILL_DIR}/../../devkit/skills/devkit/registry.json`

Execute the destroy:
```
devkit destroy <stack-name> --force
```

This will:
- Stop all containers in reverse dependency order
- Remove volumes
- Remove the Docker network `devkit-<stack-name>-net`
- Delete the workspace directory `{workspace}/stacks/<stack-name>/`
- Remove the instance from `.devkit-instances.json` (with file locking)
- Free the port range

Verify the stack is gone:
```bash
docker ps --filter name=devkit-<stack-name> --format '{{.Names}}' 2>/dev/null
ls {workspace}/stacks/<stack-name>/ 2>/dev/null
```

## Step 5 — Clean up ActiveCampaign pipeline (if applicable)

Check if an ActiveCampaign (AC) pipeline or automation was created for this issue.

Look for AC-related artifacts:
```bash
# Check if there are any AC pipeline references in the stack's git history or env
grep -ri "activecampaign\|active_campaign\|AC_PIPELINE\|ac_automation" \
  {workspace}/stacks/<stack-name>/ 2>/dev/null
```

If an AC pipeline was created as part of the issue:
- Use the AC API (via MCP tools if available, or direct API calls) to delete or deactivate the pipeline
- Confirm deletion

If no AC pipeline was involved, skip this step silently.

## Step 6 — Remove webhooks (if applicable)

Check if any webhooks were created for this issue:

```bash
# Check GitLab project webhooks that might reference this stack/issue
for project_dir in {workspace}/stacks/<stack-name>/*/; do
  project=$(basename "$project_dir")
  echo "=== $project ==="
  cd "$project_dir" 2>/dev/null && glab api "projects/$(glab repo view --output json 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("id",""))')/hooks" 2>/dev/null | python3 -c "
import sys, json
hooks = json.load(sys.stdin)
for h in hooks:
    url = h.get('url', '')
    if 'devkit' in url or '<stack-name>' in url or '9${PORT_RANGE}' in url:
        print(f\"  Webhook {h['id']}: {url}\")
" 2>/dev/null
done
```

If issue-specific webhooks are found:
- Delete them via the GitLab API: `glab api --method DELETE "projects/:id/hooks/:hook_id"`
- Confirm deletion

If no webhooks were involved, skip this step silently.

## Step 7 — General cleanup

Perform a final sweep for any remaining issue-specific resources:

1. **Dangling Docker resources** — clean up any orphaned containers, networks, or volumes from this stack:
   ```bash
   # Remove any containers that somehow survived
   docker ps -a --filter name=devkit-<stack-name> -q | xargs -r docker rm -f 2>/dev/null
   # Remove the network if it still exists
   docker network rm devkit-<stack-name>-net 2>/dev/null
   # Remove dangling volumes from this stack
   docker volume ls --filter name=devkit-<stack-name> -q | xargs -r docker volume rm 2>/dev/null
   ```

2. **Remote branches** — if the source branch was not auto-deleted by the MR, clean it up:
   ```bash
   # The MR was created with --remove-source-branch, but verify
   for project_dir in {workspace}/stacks/<stack-name>/*/; do
     cd "$project_dir" 2>/dev/null
     BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
     if [ -n "$BRANCH" ] && [ "$BRANCH" != "HEAD" ]; then
       git push origin --delete "$BRANCH" 2>/dev/null && echo "Deleted remote branch: $BRANCH" || echo "Branch $BRANCH already deleted or protected"
     fi
   done
   ```

3. **Local workspace directory** — ensure the stack directory is fully removed:
   ```bash
   rm -rf {workspace}/stacks/<stack-name>
   ```

## Step 8 — Summary

Report to the user what was cleaned up:

```
## Cleanup complete for <ISSUE-ID>

- [x] Devkit stack `<stack-name>` destroyed (containers, volumes, network, workspace)
- [x] Port range <start>-<end> freed
- [x/skip] AC pipeline deleted / No AC pipeline found
- [x/skip] Webhooks removed / No webhooks found
- [x] Dangling Docker resources cleaned
- [x/skip] Remote branches deleted / Already deleted by MR
- [x] Local workspace removed

The issue is fully closed out.
```

## Important rules
- **Never clean up if the MR is still open** — this is the most critical rule. Always verify merge status first.
- If the pipeline is still running, warn the user and let them decide.
- Use `--force` on devkit destroy to skip interactive confirmation (the user already confirmed by running `/complete`).
- Be thorough — check for every type of resource that `/solve` or manual work might have created.
- Report what was cleaned and what was skipped so the user has a clear audit trail.
- If any cleanup step fails, log the error and continue with the remaining steps. Do not abort the entire cleanup because one step failed.
- At the end, the system should be in the exact same state as before `/solve` was run — no leftover containers, ports, branches, or files.
