#!/usr/bin/env bash
# S178-L1: fail on any Claude attribution in any commit reachable from REV (default HEAD).
# Reads each raw commit object (headers + message), case-insensitive.
#   scripts/check-attribution.sh [REV]
#   scripts/check-attribution.sh --self-test
set -euo pipefail

PATTERN='co-authored-by:.*(claude|anthropic)|generated (with|by) .*claude|claude\.(ai|com)/|noreply@anthropic\.com|^(author|committer) [^<]*(claude|anthropic)'

check() {
  local rev="${1:-HEAD}" bad=0
  for sha in $(git rev-list "$rev"); do
    if git cat-file commit "$sha" | grep -qiE "$PATTERN"; then
      echo "Claude attribution in commit $sha:"
      git cat-file commit "$sha" | grep -iE "$PATTERN" | sed 's/^/  /'
      bad=1
    fi
  done
  [ "$bad" -eq 0 ] && echo "no Claude attribution in $(git rev-list --count "$rev") commits"
  return "$bad"
}

if [ "${1:-}" = "--self-test" ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  git -C "$tmp" init -q
  c() { git -C "$tmp" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m "$1"; }
  c "clean commit"
  (cd "$tmp" && check HEAD >/dev/null) || { echo "self-test: clean history flagged"; exit 1; }
  for msg in $'x\n\nCo-Authored-By: Claude Opus <noreply@anthropic.com>' $'x\n\nco-authored-by: CLAUDE' $'x\n\n\xf0\x9f\xa4\x96 Generated with [Claude Code](https://claude.com/claude-code)'; do
    c "$msg"
    if (cd "$tmp" && check HEAD >/dev/null); then echo "self-test: missed: $msg"; exit 1; fi
    git -C "$tmp" reset -q --hard HEAD~1
  done
  echo "self-test passed"
  exit 0
fi

check "${1:-HEAD}"
