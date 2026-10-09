#!/usr/bin/env bash
set -euo pipefail

NSURATOR_MEDIA_TOOLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
NSURATOR_MEDIA_TOOLS_LOCK="${NSURATOR_MEDIA_TOOLS_LOCK:-$NSURATOR_MEDIA_TOOLS_ROOT/Config/media-tools-artifact.lock.json}"

mt_die() {
  echo "error: $*" >&2
  exit 65
}

mt_json_value() {
  /usr/bin/plutil -extract "$2" raw -o - "$1"
}

mt_sha256() {
  /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

mt_require_command() {
  command -v "$1" >/dev/null 2>&1 || mt_die "required command not found: $1"
}

mt_is_system_dependency() {
  case "$1" in
    /System/Library/*|/usr/lib/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

mt_non_system_dependencies() {
  local executable="$1"
  local dependency
  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    if ! mt_is_system_dependency "$dependency"; then
      printf '%s\n' "$dependency"
    fi
  done < <(/usr/bin/otool -L "$executable" | /usr/bin/awk 'NR > 1 {print $1}')
}

mt_assert_system_dependencies_only() {
  local executable="$1"
  local non_system
  non_system="$(mt_non_system_dependencies "$executable")"
  [[ -z "$non_system" ]] || {
    echo "error: media tool has non-system dynamic dependencies: $executable" >&2
    printf '%s\n' "$non_system" >&2
    return 65
  }
}

mt_filter_is_available() {
  local ffmpeg="$1"
  local filter="$2"
  "$ffmpeg" -hide_banner -filters 2>/dev/null |
    /usr/bin/awk -v expected="$filter" '$2 == expected {found = 1} END {exit(found ? 0 : 1)}'
}
