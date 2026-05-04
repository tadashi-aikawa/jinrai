#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

INIT_FILE="$ROOT_DIR/Jinrai.spoon/init.lua"
README_FILE="$ROOT_DIR/README.ja.md"
RELEASE_BRANCH="main"
REMOTE_NAME="origin"
YES=0
SKIP_CODEX=0
VERSION=""

usage() {
  cat <<USAGE
Usage: scripts/release.sh [--yes] [--skip-codex] <version>

Examples:
  scripts/release.sh 0.13.0
  scripts/release.sh --yes --skip-codex 0.13.0
USAGE
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

validate_semver() {
  local version="$1"
  if [[ ! "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    die "Invalid SemVer: $version"
  fi
}

is_greater_version() {
  local next="$1"
  local current="$2"
  local next_major next_minor next_patch
  local current_major current_minor current_patch

  validate_semver "$next"
  validate_semver "$current"
  IFS=. read -r next_major next_minor next_patch <<<"$next"
  IFS=. read -r current_major current_minor current_patch <<<"$current"

  if ((next_major > current_major)); then return 0; fi
  if ((next_major < current_major)); then return 1; fi
  if ((next_minor > current_minor)); then return 0; fi
  if ((next_minor < current_minor)); then return 1; fi
  ((next_patch > current_patch))
}

current_version() {
  sed -nE 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"([^"]+)"[[:space:]]*,[[:space:]]*$/\1/p' "$INIT_FILE" | head -n 1
}

update_version() {
  local version="$1"
  local tmp
  tmp="$(mktemp)"
  awk -v version="$version" '
    /^[[:space:]]*version[[:space:]]*=/ {
      sub(/"[^"]+"/, "\"" version "\"")
      updated = 1
    }
    { print }
    END {
      if (!updated) {
        exit 42
      }
    }
  ' "$INIT_FILE" >"$tmp" || {
    rm -f "$tmp"
    die "Failed to update version in $INIT_FILE"
  }
  mv "$tmp" "$INIT_FILE"
}

confirm_release() {
  local version="$1"
  if ((YES == 1)); then
    return
  fi

  echo "Release v$version from $RELEASE_BRANCH and push to $REMOTE_NAME."
  read -r -p "Continue? [y/N] " answer
  case "$answer" in
  y | Y | yes | YES) ;;
  *) die "Release cancelled" ;;
  esac
}

generate_bluesky_message() {
  local version="$1"
  local previous_tag="$2"
  local output_file
  output_file="$(mktemp)"

  if ! command -v codex >/dev/null 2>&1; then
    echo "Codex CLI is not available. Skipping Bluesky message generation." >&2
    return
  fi

  local log_range
  if [[ -n "$previous_tag" ]]; then
    log_range="$previous_tag..HEAD~1"
  else
    log_range="HEAD~1"
  fi

  {
    echo "JINRAI v$version のBluesky投稿文を日本語で1案作成してください。"
    echo
    echo "条件:"
    echo "- 300文字以内"
    echo "- リリースURLを含める: https://github.com/tadashi-aikawa/jinrai/releases/tag/v$version"
    echo "- 変更点をユーザー向けに簡潔に要約"
    echo "- 1行目は『⚡️JINRAI v$version をリリース🚀』の形式"
    echo "- 投稿本文だけを出力"
    echo
    echo "README概要:"
    sed -n '1,80p' "$README_FILE"
    echo
    echo "前回リリース以降のコミット:"
    git log --oneline "$log_range"
  } | codex exec \
    --sandbox read-only \
    --output-last-message "$output_file" \
    -

  echo
  echo "Bluesky post draft:"
  cat "$output_file"
  echo
  rm -f "$output_file"
}

while (($# > 0)); do
  case "$1" in
  --yes | -y)
    YES=1
    shift
    ;;
  --skip-codex)
    SKIP_CODEX=1
    shift
    ;;
  --help | -h)
    usage
    exit 0
    ;;
  -*)
    die "Unknown option: $1"
    ;;
  *)
    if [[ -n "$VERSION" ]]; then
      die "Version is specified more than once"
    fi
    VERSION="$1"
    shift
    ;;
  esac
done

[[ -n "$VERSION" ]] || {
  usage
  exit 1
}

validate_semver "$VERSION"

require_command git
require_command sed
require_command awk
require_command mktemp
require_command busted
require_command zip

cd "$ROOT_DIR"

[[ -f "$INIT_FILE" ]] || die "init.lua not found: $INIT_FILE"
[[ "$(git branch --show-current)" == "$RELEASE_BRANCH" ]] || die "Release must run on $RELEASE_BRANCH"
[[ -z "$(git status --short)" ]] || die "Working tree must be clean before release"

git fetch "$REMOTE_NAME" "$RELEASE_BRANCH" --tags

local_head="$(git rev-parse HEAD)"
remote_head="$(git rev-parse "$REMOTE_NAME/$RELEASE_BRANCH")"
[[ "$local_head" == "$remote_head" ]] || die "Local $RELEASE_BRANCH must match $REMOTE_NAME/$RELEASE_BRANCH"

tag_name="v$VERSION"
if git rev-parse -q --verify "refs/tags/$tag_name" >/dev/null; then
  die "Tag already exists: $tag_name"
fi

current="$(current_version)"
[[ -n "$current" ]] || die "Failed to parse current version from $INIT_FILE"
is_greater_version "$VERSION" "$current" || die "Release version must be greater than current version: $current"

previous_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"

confirm_release "$VERSION"

update_version "$VERSION"

busted
"$SCRIPT_DIR/build_spoon_dist.sh"
"$SCRIPT_DIR/validate_spoon_dist.sh"

git diff -- "$INIT_FILE"
git add "$INIT_FILE"
git commit -m "chore: v$VERSION"
git tag "$tag_name"

if ((SKIP_CODEX == 0)); then
  generate_bluesky_message "$VERSION" "$previous_tag"
else
  echo "Skipping Bluesky message generation."
fi

git push "$REMOTE_NAME" "$RELEASE_BRANCH"
git push "$REMOTE_NAME" "$tag_name"

echo "Released $tag_name. Spoon distribution will be published by GitHub Actions."
