#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="${1:-}"
APP="$ROOT_DIR/.build/JINRAI.app"
DIST_DIR="$ROOT_DIR/dist"
ARCHIVE="$DIST_DIR/JINRAI-$VERSION.zip"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Usage: scripts/build_release.sh <version>" >&2
  exit 1
fi

"$SCRIPT_DIR/make-app.sh" release "$VERSION"

# ad-hoc フォールバックのままリリースする事故を防ぐ。
# CI 以外(ローカル検証)では jinrai-dev 証明書が無いことがあるためスキップする
if [[ "${CI:-}" == "true" ]]; then
  codesign -dvv "$APP" 2>&1 | tee /dev/stderr | grep -q "Authority=jinrai-dev"
fi

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# ditto zip: 拡張属性・署名メタデータを保持しつつダブルクリック展開できる。
# --keepParent が無いと展開時に JINRAI.app の中身がばらける
ditto -c -k --keepParent "$APP" "$ARCHIVE"

unzip -tq "$ARCHIVE"
unzip -Z1 "$ARCHIVE" | grep -qx "JINRAI.app/Contents/Info.plist"

echo "Built and validated $ARCHIVE (version $VERSION)"
