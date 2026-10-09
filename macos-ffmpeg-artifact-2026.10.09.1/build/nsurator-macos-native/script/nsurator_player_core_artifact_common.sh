#!/usr/bin/env bash
set -euo pipefail

NSURATOR_NATIVE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NSURATOR_NATIVE_NPC_SOURCE_LOCK="${NSURATOR_NATIVE_NPC_SOURCE_LOCK:-$NSURATOR_NATIVE_ROOT/Config/nsurator-player-core-ffmpeg-sources.json}"

npc_json_value() {
  local file="$1"
  local key="$2"
  /usr/bin/plutil -extract "$key" raw -o - "$file"
}

npc_sha256() {
  /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

npc_json_array_contains() {
  local file="$1"
  local key="$2"
  local expected="$3"
  local count index value
  count="$(npc_json_value "$file" "$key")"
  for ((index = 0; index < count; index += 1)); do
    value="$(npc_json_value "$file" "$key.$index")"
    if [[ "$value" == "$expected" ]]; then
      return 0
    fi
  done
  return 1
}

npc_require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: required command not found: $1" >&2
    return 66
  }
}

npc_core_root() {
  local core_root="${NSURATOR_NATIVE_PLAYER_CORE_PACKAGE_ROOT:-$NSURATOR_NATIVE_ROOT/.build/checkouts/nsurator-player-core}"
  test -x "$core_root/scripts/build-ffmpeg-apple.sh" || {
    echo "error: NsuratorPlayerCore checkout is unavailable: $core_root" >&2
    return 66
  }
  local expected_revision
  expected_revision="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" packageRevision)"
  local actual_revision
  actual_revision="$(git -C "$core_root" rev-parse HEAD)"
  test "$actual_revision" = "$expected_revision" || {
    echo "error: NsuratorPlayerCore revision mismatch: expected $expected_revision, found $actual_revision" >&2
    return 65
  }
  printf '%s\n' "$core_root"
}

npc_manifest_path() {
  printf '%s/nsurator-player-core-ffmpeg-apple-manifest.json\n' "${1%/}"
}

npc_path_is_within() {
  local child="${1%/}/"
  local parent="${2%/}/"
  [[ "$child" == "$parent"* ]]
}
