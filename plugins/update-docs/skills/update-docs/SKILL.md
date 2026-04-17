---
name: update-docs
description: >
  Check a repo's commits since the hash in last_documented_commit, decide if
  anything warrants a docs update, and push changes to the central docs repo.
argument-hint: <repo-name-or-path>
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# update-docs

Incrementally document a project repo by checking what changed since the last run.

## 1. Resolve repo path

From `$ARGUMENTS`, try in order:
1. Absolute path as-is
2. `~/dev/$ARGUMENTS`
3. Glob `~/dev/$ARGUMENTS*` — use first match

If not found, stop and tell the user.

## 2. Get commit range

```bash
REPO=<resolved-path>
LAST=$(cat "$REPO/last_documented_commit" 2>/dev/null)
HEAD=$(git -C "$REPO" rev-parse HEAD)
```

- If `last_documented_commit` doesn't exist → use `HEAD~30` as `LAST`, warn the user.
- If `LAST == HEAD` → print "Already up to date." and stop.

```bash
git -C "$REPO" log "$LAST..$HEAD" --oneline --no-merges
```

If the log is empty → print "Already up to date." and stop.

## 3. Assess scope cheaply

```bash
git -C "$REPO" diff "$LAST..$HEAD" --stat
```

**Skip entirely** (no docs needed) if all changed files match: `package-lock.json`, `yarn.lock`, `composer.lock`, `*.log`, `.env*`, `*.config.js` (trivial).

Otherwise continue.

## 4. Read targeted diffs

Do **not** read the full diff. For each area, read only what's relevant:

```bash
# New/deleted files
git -C "$REPO" diff "$LAST..$HEAD" --diff-filter=AD --name-only

# Changes to meaningful paths
git -C "$REPO" diff "$LAST..$HEAD" -- src/ app/ routes/ config/ CLAUDE.md docs/
```

Read file-by-file. Stop reading a file once you have enough to judge its impact.

## 5. Decide what to document

| Change | Where to write |
|---|---|
| New endpoint / route | `docs/api.md` in source repo |
| New service / module | `docs/architecture.md` in source repo |
| Setup or env var change | `docs/setup.md` in source repo |
| Stack / framework change | `CLAUDE.md` + `docs/` in source repo |
| New CLI command or script | `CLAUDE.md` commands section |
| Cross-project integration | central docs repo only |
| Refactor / rename | Skip unless it changes how to use the code |
| Only tests / styles / lock files | Skip |

If nothing qualifies → jump straight to step 8.

## 6. Locate / clone docs repo

```bash
DOCS_DIR=~/dev/docs
if [ ! -d "$DOCS_DIR/.git" ]; then
  git clone https://github.com/harbourspace-org/docs.git "$DOCS_DIR"
else
  git -C "$DOCS_DIR" pull --rebase
fi
```

## 7. Write documentation updates

- **Source repo** (`$REPO/docs/` or `$REPO/CLAUDE.md`): project-scoped changes.
- **Central docs repo** (`$DOCS_DIR`): cross-project or integration content only.

Guidelines (keep it tight):
- Concrete file paths and command examples
- No filler prose
- Don't duplicate CLAUDE.md content in docs/
- kebab-case filenames, singular topics (`auth.md` not `authentication.md`)

If adding a new docs file to the central repo, add a nav entry to `$DOCS_DIR/mkdocs.yml`.

Commit source repo changes (if any):
```bash
git -C "$REPO" add docs/ CLAUDE.md
git -C "$REPO" commit -m "docs: update documentation through ${HEAD:0:7}"
```

Commit and push docs repo changes (if any):
```bash
git -C "$DOCS_DIR" add .
git -C "$DOCS_DIR" commit -m "docs($(basename $REPO)): sync updates through ${HEAD:0:7}"
git -C "$DOCS_DIR" pull --rebase && git -C "$DOCS_DIR" push
```

## 8. Update last_documented_commit

```bash
echo "$HEAD" > "$REPO/last_documented_commit"
git -C "$REPO" add last_documented_commit
git -C "$REPO" commit -m "docs: advance last_documented_commit to ${HEAD:0:7}"
git -C "$REPO" pull --rebase && git -C "$REPO" push
```

Report to the user what was documented and what was skipped.
