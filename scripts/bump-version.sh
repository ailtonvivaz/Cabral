#!/usr/bin/env bash
# Usage: scripts/bump-version.sh x.y.z  -> sets MARKETING_VERSION, increments CURRENT_PROJECT_VERSION, commits, tags vX.Y.Z
set -euo pipefail
cd "$(dirname "$0")/.."
V="${1:?usage: bump-version.sh x.y.z}"
[[ "$V" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || { echo "bad version: $V" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "working tree dirty" >&2; exit 1; }
grep -q "^## \[$V\]" CHANGELOG.md || { echo "add a '## [$V]' section to CHANGELOG.md first" >&2; exit 1; }
BUILD=$(sed -nE 's/^[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*"?([0-9]+)"?.*/\1/p' project.yml | head -1)
NEXT=$((BUILD + 1))
sed -i '' -E "s/^([[:space:]]*MARKETING_VERSION:[[:space:]]*).*/\1\"$V\"/" project.yml
sed -i '' -E "s/^([[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*).*/\1\"$NEXT\"/" project.yml
git add project.yml && git commit -m "chore: release v$V" && git tag -a "v$V" -m "Cabral $V"
echo "Next: git push origin main --follow-tags"
