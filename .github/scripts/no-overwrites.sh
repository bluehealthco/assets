#!/usr/bin/env sh
# Refuses content changes to assets that are already tracked.
#
# assets.bluehealth.co caches every path for a year at the edge AND in the
# browser, so replacing the bytes behind a live filename is not undoable: a purge
# clears Cloudflare, but nothing evicts a copy a browser already holds.
#
# Single source of truth for all three callers — the PR check
# (.github/workflows/immutability.yml), the pre-sync guard
# (.github/workflows/sync-r2.yml) and the optional pre-commit hook
# (.githooks/pre-commit) — so the rule cannot drift between them.
#
# Usage:
#   no-overwrites.sh --staged        # what is staged right now
#   no-overwrites.sh <base> <head>   # a range
#
# Exits 0 when nothing is overwritten, 1 otherwise. Adds, renames and deletes are
# always fine: a rename is a new URL, and a delete leaves the object in the
# bucket because the sync runs without --delete.
set -eu

# The repo's own tooling and docs are not published assets.
EXCLUDES=". :!.github :!README.md :!.githooks"

if [ "${1:-}" = "--staged" ]; then
  # shellcheck disable=SC2086
  modified=$(git diff --cached --name-only --diff-filter=M -- $EXCLUDES)
else
  base=${1:?base commit required}
  head=${2:?head commit required}
  # shellcheck disable=SC2086
  modified=$(git diff --name-only --diff-filter=M "$base" "$head" -- $EXCLUDES)
fi

if [ -z "$modified" ]; then
  echo "No tracked asset was modified."
  exit 0
fi

cat >&2 <<EOF

These assets already exist and would be given different bytes:

$(printf '%s\n' "$modified" | sed 's/^/  /')

Published assets are immutable. assets.bluehealth.co caches every path for a
year at the edge and in the browser, so a replaced file cannot be recalled —
kiosks and phones keep serving the old one until their cache is cleared by hand.

Instead:
  1. Add the new bytes under a NEW filename. This repo versions by dimension
     (img/model-front-f-presentation-@2134x2160.webp); a suffix (-v2, a date,
     the new size) works too.
  2. Point the app code at the new path and run the assets codegen in the
     bluehealth repo.
  3. Leave the old file in place until nothing references it — including shipped
     native builds, which bake asset URLs in.

EOF
exit 1
