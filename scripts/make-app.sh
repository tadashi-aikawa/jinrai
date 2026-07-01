#!/usr/bin/env bash
# swift build → Jinrai.app 組み立て → ad-hoc 署名
# 使い方: ./scripts/make-app.sh [debug|release] [version]
set -euo pipefail

CONFIG="${1:-debug}"
VERSION="${2:-0.0.0-development}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/Jinrai.app"

swift build --package-path "$ROOT" -c "$CONFIG"

BIN="$ROOT/.build/$CONFIG/Jinrai"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Jinrai"
sed "s/0\.0\.0-development/$VERSION/" "$ROOT/Resources/Info.plist" > "$APP/Contents/Info.plist"

# ad-hoc 署名。TCC の許可が剥がれた場合は:
#   tccutil reset Accessibility com.tadashi-aikawa.jinrai
codesign --force --sign - "$APP"

echo "Built: $APP"
echo "Run:   open '$APP'"
