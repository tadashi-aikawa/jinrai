#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${1:-}"
SOURCE_DIR="$ROOT_DIR/Jinrai.spoon"
DIST_DIR="$ROOT_DIR/dist"
DIST_SPOON_DIR="$DIST_DIR/Jinrai.spoon"
ARCHIVE="$DIST_DIR/Jinrai.spoon.zip"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Usage: scripts/build_release.sh <version>" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
cp -R "$SOURCE_DIR" "$DIST_SPOON_DIR"

sed -i.bak -E \
  "s/^([[:space:]]*version[[:space:]]*=[[:space:]]*)\"[^\"]+\"/\\1\"$VERSION\"/" \
  "$DIST_SPOON_DIR/init.lua"
rm "$DIST_SPOON_DIR/init.lua.bak"

grep -Fq "version = \"$VERSION\"" "$DIST_SPOON_DIR/init.lua"

(
  cd "$DIST_DIR"
  zip -r -q "Jinrai.spoon.zip" "Jinrai.spoon" -x "*.DS_Store" "*/.DS_Store"
)

unzip -tq "$ARCHIVE"
unzip -Z1 "$ARCHIVE" | grep -qx "Jinrai.spoon/init.lua"

echo "Built and validated $ARCHIVE (version $VERSION)"
