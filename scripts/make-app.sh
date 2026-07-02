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

# 署名: "jinrai-dev" という自己署名証明書が Keychain にあればそれを使う(署名が固定され
# TCC の許可が再ビルドでも維持される)。なければ ad-hoc 署名。
# ad-hoc で TCC の許可が剥がれた場合は:
#   tccutil reset Accessibility com.tadashi-aikawa.jinrai
# 自己署名のコード署名証明書は「信頼」設定が無くても署名に使えるため、
# find-identity は -v(valid のみ)を付けずに検索する。
if security find-identity -p codesigning 2>/dev/null | grep -q "jinrai-dev" \
    && codesign --force --sign "jinrai-dev" "$APP" 2>/dev/null; then
    echo "Signed with: jinrai-dev"
else
    codesign --force --sign - "$APP"
    echo "Signed with: ad-hoc"
fi

echo "Built: $APP"
echo "Run:   open '$APP'"
