#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SPOON_NAME="Jinrai"
ZIP_FILE="$ROOT_DIR/dist/Spoons/${SPOON_NAME}.spoon.zip"
DOCS_JSON="$ROOT_DIR/dist/docs/docs.json"

if [[ ! -f "$ZIP_FILE" ]]; then
  echo "Missing Spoon archive: $ZIP_FILE" >&2
  exit 1
fi

if [[ ! -f "$DOCS_JSON" ]]; then
  echo "Missing docs.json: $DOCS_JSON" >&2
  exit 1
fi

python3 - "$ZIP_FILE" "$SPOON_NAME" <<'PY'
import sys
import zipfile

zip_file, spoon_name = sys.argv[1:3]
required_path = f"{spoon_name}.spoon/init.lua"

with zipfile.ZipFile(zip_file) as zf:
    names = set(zf.namelist())
    if required_path not in names:
        raise SystemExit(f"Missing {required_path} in {zip_file}")
PY

python3 - "$DOCS_JSON" "$SPOON_NAME" <<'PY'
import json
import sys

docs_json, spoon_name = sys.argv[1:3]
required_keys = ["name", "desc", "author", "homepage", "license", "version"]

with open(docs_json, "r", encoding="utf-8") as f:
    data = json.load(f)

if not isinstance(data, list):
    raise SystemExit(f"docs.json must be a list: {docs_json}")

entry = next((v for v in data if isinstance(v, dict) and v.get("name") == spoon_name), None)
if entry is None:
    raise SystemExit(f"docs.json does not include entry for {spoon_name}")

missing = [key for key in required_keys if not entry.get(key)]
if missing:
    raise SystemExit(f"docs.json entry for {spoon_name} is missing required keys: {', '.join(missing)}")
PY

echo "Validated Spoon distribution: $ZIP_FILE and $DOCS_JSON"
