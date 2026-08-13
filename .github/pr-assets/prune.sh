#!/usr/bin/env bash
# Delete the oldest PR review assets until this folder is back under the size cap.
#
# Sorts by last-commit date, not mtime: git does not preserve modification times, so
# in a fresh clone every file here has the same mtime and `ls -t` tells you nothing.
#
#   ./prune.sh           dry run, prints exactly what --apply would remove
#   ./prune.sh --apply   git rm the oldest files (review, then commit yourself)
#   CAP_MB=50 ./prune.sh tighter cap for this run
set -euo pipefail

cd "$(dirname "$0")"
CAP_MB="${CAP_MB:-100}"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

# Files that belong to the folder itself and are never pruned.
KEEP='^(README\.md|prune\.sh|\.gitattributes|\.gitkeep)$'

cap_kb=$((CAP_MB * 1024))
used_kb=$(du -sk . 2>/dev/null | cut -f1)

printf 'pr-assets: %sMB used, %sMB cap\n' "$((used_kb / 1024))" "$CAP_MB"

if [ "$used_kb" -le "$cap_kb" ]; then
  echo "Under cap — nothing to prune."
  exit 0
fi

# Oldest first, by the commit that last touched each file.
listing=$(
  git ls-files -z . \
    | while IFS= read -r -d '' f; do
        base=${f##*/}
        printf '%s' "$base" | grep -qE "$KEEP" && continue
        [ -f "$f" ] || continue
        printf '%s\t%s\n' "$(git log -1 --format=%ct -- "$f" 2>/dev/null || echo 0)" "$f"
      done \
    | sort -n | cut -f2
)

if [ -z "$listing" ]; then
  echo "Over cap, but no prunable assets are tracked here."
  exit 0
fi

# Walk oldest-first, subtracting each file from a running total, so the dry run
# reports exactly the same set that --apply would delete.
doomed=()
running_kb=$used_kb
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ "$running_kb" -le "$cap_kb" ] && break
  fkb=$(du -sk -- "$f" 2>/dev/null | cut -f1)
  doomed+=("$f")
  running_kb=$((running_kb - fkb))
done <<< "$listing"

if [ "${#doomed[@]}" -eq 0 ]; then
  echo "Nothing to prune."
  exit 0
fi

for f in "${doomed[@]}"; do
  when=$(git log -1 --format=%as -- "$f" 2>/dev/null || echo '?')
  sz=$(du -sh -- "$f" 2>/dev/null | cut -f1)
  if [ "$APPLY" -eq 1 ]; then
    git rm -q -- "$f"
    printf '  removed       %-52s %6s  last touched %s\n' "$f" "$sz" "$when"
  else
    printf '  would remove  %-52s %6s  last touched %s\n' "$f" "$sz" "$when"
  fi
done

printf '\n%s files, %sMB -> %sMB\n' \
  "${#doomed[@]}" "$((used_kb / 1024))" "$((running_kb / 1024))"

if [ "$APPLY" -eq 1 ]; then
  echo 'Staged with `git rm`. Review with `git status`, then commit.'
else
  echo 'Dry run — nothing deleted. Re-run with --apply to remove these.'
fi
