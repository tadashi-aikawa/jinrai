#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${1:-}"
ARCHIVE="$ROOT_DIR/dist/JINRAI-$VERSION.zip"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Usage: scripts/update_tap.sh <version>" >&2
  exit 1
fi

if [[ -z "${TAP_GITHUB_TOKEN:-}" ]]; then
  echo "TAP_GITHUB_TOKEN is required." >&2
  exit 1
fi

SHA256=$(shasum -a 256 "$ARCHIVE" | cut -d' ' -f1)
TAP_DIR="$(mktemp -d)/tap"

git clone "https://x-access-token:${TAP_GITHUB_TOKEN}@github.com/tadashi-aikawa/homebrew-tap.git" "$TAP_DIR"
cd "$TAP_DIR"
sed -i '' \
  -e "s/^  version .*/  version \"$VERSION\"/" \
  -e "s/^  sha256 .*/  sha256 \"$SHA256\"/" \
  Casks/jinrai.rb
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git commit -am "jinrai $VERSION"
git push

echo "Updated homebrew-tap: jinrai $VERSION ($SHA256)"
