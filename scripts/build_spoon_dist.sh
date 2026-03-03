#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SPOON_NAME="Jinrai"
SPOON_DIR="$ROOT_DIR/${SPOON_NAME}.spoon"
INIT_FILE="$SPOON_DIR/init.lua"
DIST_DIR="$ROOT_DIR/dist"
DOCS_DIR="$DIST_DIR/docs"
SPOONS_DIR="$DIST_DIR/Spoons"
DESC="A Hammerspoon script for switching and recognizing windows at the speed of thought."

if [[ ! -f "$INIT_FILE" ]]; then
  echo "init.lua not found: $INIT_FILE" >&2
  exit 1
fi

extract_metadata() {
  local key="$1"
  sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]+)\"[[:space:]]*,[[:space:]]*$/\\1/p" "$INIT_FILE" | head -n 1
}

name="$(extract_metadata name)"
version="$(extract_metadata version)"
author="$(extract_metadata author)"
license_name="$(extract_metadata license)"
homepage="$(extract_metadata homepage)"

for value_name in name version author license_name homepage; do
  if [[ -z "${!value_name}" ]]; then
    echo "Failed to parse ${value_name} from $INIT_FILE" >&2
    exit 1
  fi
done

if [[ "$name" != "$SPOON_NAME" ]]; then
  echo "Spoon name mismatch: expected $SPOON_NAME, got $name" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$DOCS_DIR" "$SPOONS_DIR"
touch "$DIST_DIR/.nojekyll"

(
  cd "$ROOT_DIR"
  zip -r -q "$SPOONS_DIR/${SPOON_NAME}.spoon.zip" "${SPOON_NAME}.spoon" -x "*.DS_Store" "*/.DS_Store"
)

python3 - "$DOCS_DIR/docs.json" "$name" "$DESC" "$author" "$homepage" "$license_name" "$version" <<'PY'
import json
import sys

output_file, name, desc, author, homepage, license_name, version = sys.argv[1:8]
docs = [
    {
        "name": name,
        "desc": desc,
        "author": author,
        "homepage": homepage,
        "license": license_name,
        "version": version,
    }
]
with open(output_file, "w", encoding="utf-8") as f:
    json.dump(docs, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

echo "Built Spoon distribution at $DIST_DIR"
