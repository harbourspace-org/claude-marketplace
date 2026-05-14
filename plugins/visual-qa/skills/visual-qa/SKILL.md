---
name: visual-qa
description: Use this skill when the user asks about visual-qa, visual regression testing for harbour.space, qa.harbour.space, reviewing pending pages or diffs, approving / rejecting baselines, triggering screenshot runs (quick / full / specific), or linking regressions to Linear. The companion `visual-qa-mcp` MCP server provides the tools that act on the live system; this skill gives you the mental model and workflow guidance for using them well.
---

# Visual QA at Harbour.Space

**What it is.** A Fastify + BullMQ service at https://qa.harbour.space that crawls harbour.space, captures viewport screenshots, diffs them against approved baselines, and surfaces regressions for human (or Claude) review. The deployment lives on Dokploy (host `docs-prod`), with Postgres for run/page state and DO Spaces for screenshot storage.

**Why it matters.** Before each major frontend deploy somebody used to click through pages by hand to spot visual regressions. This service automates the capture + diff side; reviewers (you) confirm whether each diff is a real regression or expected churn.

## Run modes

| Mode | When | What |
|---|---|---|
| `quick` | Daily cron + ad-hoc smoke tests | ~38 curated pages from `QUICK_PAGES`, 3–4 min |
| `full` | Weekly cron + before a big release | Every URL in the sitemap (~1700 pages, hours) |
| `specific` | Targeted investigation of a section | Pages whose URL path includes `path_segment` (e.g. `articles`, `barcelona`, `bachelor`) |

`trigger_run` takes the mode as required input. Never assume `quick` — ask the user when it's ambiguous.

## Page result statuses

- **`new`** — no prior baseline existed; current capture became the seed baseline. Usually expected for newly-added pages.
- **`pending`** — diff exceeds the threshold (`REGRESSION_THRESHOLD_PCT=0.01` by default). **This is what reviewers act on**: approve to set the new screenshot as baseline, reject to leave it flagged.
- **`auto_ok`** — diff under the threshold; the runner threw the screenshot away. No action needed.
- **`error`** — the page couldn't be captured (timeout, crashed tab, etc.). Look at `error_message`.

## Typical workflows

### Triage a recent run

1. `list_runs({ limit: 5 })` — find the last completed run with `pending > 0`.
2. `list_pending_pages({ runId })` — get the pending rows.
3. For each pending row: `view_page_diff({ runId, pageResultId })` — the diff PNG arrives inline (tall images are sliced into ~1600 px chunks so detail is preserved). Look at the highlighted pixel deltas.
4. Decide:
   - Trivial layout shift, antialiasing, font hinting → `approve_page` (becomes the new baseline)
   - Genuine bug → `reject_page` with a one-line reason, then `link_linear_issue` to file it in HSDEV

### Trigger a targeted run

When the user is poking at one section: `trigger_run({ mode: 'specific', path_segment: '<segment>' })`. To see what segments exist, `list_sitemap_categories` first.

### Kick the daily smoke test by hand

`trigger_run({ mode: 'quick' })` — same thing the cron would do at 08:00 UTC.

### Stop a misfired run

`cancel_run({ runId })`. The runner trips its cancellation flag on its next 3-second poll and tears down the browser; the cancelled notification lands in Telegram + Slack from the API side (instant).

## Things to know that aren't obvious from the schemas

- **The user reviews from `https://qa.harbour.space`** by hand today. The MCP exists so you can do the same thing through Claude — they're peers, not replacements.
- **Diff images are stored in DO Spaces** (S3-backed) and proxied through `/images/...`. The MCP fetches the PNG via that proxy. No direct disk access from outside the host.
- **Only one run can be queued or running at a time** — `trigger_run` returns 409 if you try to start a second one. Cancel the first before queuing another.
- **Approving a page that was never re-captured fails with 409.** If the current screenshot is no longer on disk (cleaned up by `CRON_CLEANUP`), trigger a fresh run before approving.
- **`linear_issue` calls 501 if `LINEAR_API_KEY` isn't set on the server.** Not a crash, just informative.
- **`auto_ok` rows don't have a `diff_image_path`** — `view_page_diff` returns a note instead of an image for them. That's normal.

## Configuration the user controls

- `VISUAL_QA_API_TOKEN` — Bearer token, required. Pulled from the visual-qa Dokploy env (`API_TOKEN`).
- `VISUAL_QA_BASE_URL` — defaults to `https://qa.harbour.space`. Override for staging or local dev.

## When NOT to use the MCP

- The user is editing the visual-qa repo source code, not interacting with running visual-qa workflow. (Then the repo at `harbourspace-org/visual-qa` is the right context, not this MCP.)
- The user is debugging the MCP server itself. Then read `tools.ts` and `api.ts` directly.
