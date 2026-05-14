# visual-qa — Drive Visual Regression Review from Claude

Triage pending pages, view diffs at native resolution, approve/reject baselines, trigger runs, and file Linear issues for the [visual-qa](https://qa.harbour.space) service — all from Claude Code.

The plugin ships the **skill** that gives Claude the mental model (run modes, page statuses, typical workflows). The actual tools are provided by the companion **MCP server** at [`harbourspace-org/visual-qa-mcp`](https://github.com/harbourspace-org/visual-qa-mcp), which you register separately with `claude mcp add`.

## Prerequisites

| Requirement | Install | Verify |
|---|---|---|
| **Node.js 20+** | [nodejs.org](https://nodejs.org/) | `node --version` |
| **git** | shipped with macOS / `winget install Git.Git` on Windows | `git --version` |
| **visual-qa API token** | Pull from Dokploy (`API_TOKEN` env on the visual-qa project) or via Teleport: `tsh ssh root@docs-prod 'docker exec frontend-monitoring-visual-regression-runner-e6glin-app-1 printenv API_TOKEN'` | — |

## Install the companion MCP server

```bash
# 1. Clone and build the MCP server
git clone https://github.com/harbourspace-org/visual-qa-mcp.git
cd visual-qa-mcp
npm install
npm run build

# 2. Register it with Claude Code (single line — no backslashes)
claude mcp add visual-qa --scope user --env VISUAL_QA_API_TOKEN=<paste_token_here> --env VISUAL_QA_BASE_URL=https://qa.harbour.space -- node "$(pwd)/dist/index.js"

# 3. Verify
claude mcp get visual-qa
# Status: ✓ Connected
```

Open a new Claude Code session (MCPs load on boot) and run `/mcp` — you should see `visual-qa` with 10 tools.

## What the skill gives you

Once the plugin is installed (`/plugin install visual-qa@harbourspace-claude-plugins`), Claude picks up the `visual-qa` skill automatically whenever you mention visual-qa, qa.harbour.space, visual regression, pending pages, diff approval, etc. The skill teaches Claude:

- The three run modes (`quick`, `full`, `specific`) and when each fits
- The four page statuses (`new`, `pending`, `auto_ok`, `error`) and what each means for the reviewer
- The standard workflows — triage a recent run, trigger a targeted run, kick the daily smoke test, cancel a misfired run
- Gotchas that aren't obvious from the MCP tool schemas (one-run-at-a-time guard, approve-after-cleanup 409, etc.)

## Tools (provided by the MCP server)

| Tool | What it does |
|---|---|
| `list_runs` | Recent runs newest-first, optional status filter |
| `get_run` | Full detail + summary counts for one run |
| `list_pending_pages` | Pages from a run with status `pending` — the actionable ones |
| `view_page_diff` | Diff PNG returned inline; tall diffs (> 1600 px) are sliced into vertical chunks so detail survives Claude's vision pipeline |
| `approve_page` | Approve a pending page (its current screenshot becomes the new baseline) |
| `reject_page` | Reject a pending page, reason recorded in the audit log |
| `trigger_run` | Queue a `quick`, `full`, or `specific` run — reviewer picks the mode |
| `cancel_run` | Cancel a queued or running run |
| `link_linear_issue` | File a Linear issue for a regression and link it back to the page_result |
| `list_sitemap_categories` | Valid `path_segment` values for `specific` mode |

## Example session

> Claude, find the last completed visual-qa run that has pending pages, show me each diff, and approve any that are obviously just antialiasing.

Claude will call `list_runs` → `list_pending_pages` → `view_page_diff` (for each) → look at the chunks → `approve_page` for the trivial ones.

## Troubleshooting

- **`claude mcp get visual-qa` shows `Command: \`** — the `claude mcp add` paste got mangled by the shell. Run the command on a single line, no backslash continuations.
- **Tools return `Unexpected token '<'`** — `VISUAL_QA_BASE_URL` is wrong or the token is invalid; the server is returning the React UI's HTML instead of JSON. The default `https://qa.harbour.space` is correct.
- **Approve returns 409 "screenshot no longer on disk"** — `CRON_CLEANUP` already swept the run's output. Trigger a fresh run to recapture, then approve.
- **MCP not auto-installing yet** — coming once we publish `@harbourspace/visual-qa-mcp` to npm; until then, the `claude mcp add` step above is the install path.
