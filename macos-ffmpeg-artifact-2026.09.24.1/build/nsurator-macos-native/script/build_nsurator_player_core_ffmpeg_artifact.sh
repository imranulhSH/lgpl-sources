#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=nsurator_player_core_artifact_common.sh
source "$SCRIPT_DIR/nsurator_player_core_artifact_common.sh"

DRY_RUN=false
SOURCE_CACHE=""
WORK_ROOT=""
DIST_ROOT="$NSURATOR_NATIVE_ROOT/.build/nsurator-player-core-artifacts/dist"

usage() {
  cat <<'USAGE'
usage: script/build_nsurator_player_core_ffmpeg_artifact.sh [options]

Options:
  --dry-run
  --source-cache <directory>
  --work-root <directory>
  --dist-root <directory>
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --source-cache)
      SOURCE_CACHE="${2:-}"
      shift 2
      ;;
    --work-root)
      WORK_ROOT="${2:-}"
      shift 2
      ;;
    --dist-root)
      DIST_ROOT="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

if [[ "$DIST_ROOT" != /* ]]; then
  DIST_ROOT="$NSURATOR_NATIVE_ROOT/$DIST_ROOT"
fi

ARTIFACT_VERSION="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" artifactVersion)"
SLICE_NAME="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" sliceName)"
LINK_PROFILE="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" linkProfile)"
LINK_MODE="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" swiftpmLinkMode)"
NETWORK_PROTOCOLS="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" networkProtocolsEnabled)"
RUNTIME_LIBRARY_0="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" requiredRuntimeLibraries.0)"
RUNTIME_LIBRARY_1="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" requiredRuntimeLibraries.1)"

source_value() {
  npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" "sources.$1.$2"
}

if [[ "$DRY_RUN" == true ]]; then
  printf 'artifactVersion=%s\n' "$ARTIFACT_VERSION"
  printf 'slice=%s\n' "$SLICE_NAME"
  printf 'profile=%s\n' "$LINK_PROFILE"
  printf 'linkMode=%s\n' "$LINK_MODE"
  printf 'requiredRuntimeLibraries=%s %s\n' "$RUNTIME_LIBRARY_0" "$RUNTIME_LIBRARY_1"
  printf 'ffmpeg=%s\n' "$(source_value ffmpeg version)"
  printf 'dav1d=%s\n' "$(source_value dav1d version)"
  printf 'libbluray=%s\n' "$(source_value libbluray version)"
  printf 'libudfread=%s\n' "$(source_value libudfread version)"
  printf 'networkProtocolsEnabled=%s\n' "$NETWORK_PROTOCOLS"
  printf 'distRoot=%s\n' "$DIST_ROOT"
  exit 0
fi

npc_require_command curl
npc_require_command pkg-config
npc_require_command tar
npc_require_command xcrun
MESON_EXECUTABLE="${NSURATOR_PLAYER_CORE_MESON:-meson}"
if [[ "$MESON_EXECUTABLE" == */* ]]; then
  [[ -x "$MESON_EXECUTABLE" ]] || {
    echo "error: configured Meson executable is unavailable: $MESON_EXECUTABLE" >&2
    exit 66
  }
else
  npc_require_command "$MESON_EXECUTABLE"
fi
"$MESON_EXECUTABLE" --version >/dev/null

if [[ -z "$WORK_ROOT" ]]; then
  WORK_ROOT="/tmp/nsurator-npc-artifact-build-${ARTIFACT_VERSION//./}"
fi
if [[ "$WORK_ROOT" == *" "* ]]; then
  echo "error: --work-root must not contain whitespace: $WORK_ROOT" >&2
  exit 64
fi

SOURCE_ARCHIVE_ROOT="$WORK_ROOT/source-archives"
SOURCE_ROOT="$WORK_ROOT/sources"
mkdir -p "$SOURCE_ARCHIVE_ROOT" "$SOURCE_ROOT" "$DIST_ROOT"

fetch_source_archive() {
  local key="$1"
  local archive_name url expected_sha destination actual_sha
  archive_name="$(source_value "$key" archiveName)"
  url="$(source_value "$key" url)"
  expected_sha="$(source_value "$key" sha256)"
  destination="$SOURCE_ARCHIVE_ROOT/$archive_name"

  if [[ -n "$SOURCE_CACHE" && -f "$SOURCE_CACHE/$archive_name" ]]; then
    cp "$SOURCE_CACHE/$archive_name" "$destination"
  elif [[ ! -f "$destination" ]]; then
    curl -fsSL "$url" -o "$destination.download"
    mv "$destination.download" "$destination"
  fi

  actual_sha="$(npc_sha256 "$destination")"
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    echo "error: source checksum mismatch for $archive_name" >&2
    echo "expected: $expected_sha" >&2
    echo "actual:   $actual_sha" >&2
    exit 65
  fi
  printf '%s\n' "$destination"
}

extract_source_archive() {
  local archive="$1"
  case "$archive" in
    *.tar.xz)
      tar -xJf "$archive" -C "$SOURCE_ROOT"
      ;;
    *.tar.gz)
      tar -xzf "$archive" -C "$SOURCE_ROOT"
      ;;
    *)
      echo "error: unsupported source archive: $archive" >&2
      exit 65
      ;;
  esac
}

rm -rf "$SOURCE_ROOT"
mkdir -p "$SOURCE_ROOT"
for source_key in ffmpeg dav1d libbluray libudfread; do
  extract_source_archive "$(fetch_source_archive "$source_key")"
done

FFMPEG_SOURCE_DIR="$SOURCE_ROOT/ffmpeg-$(source_value ffmpeg version)"
DAV1D_SOURCE_DIR="$SOURCE_ROOT/dav1d-$(source_value dav1d version)"
LIBBLURAY_SOURCE_DIR="$SOURCE_ROOT/libbluray-$(source_value libbluray version)"
LIBUDFREAD_SOURCE_DIR="$SOURCE_ROOT/libudfread-$(source_value libudfread version)"

for required_path in \
  "$FFMPEG_SOURCE_DIR/configure" \
  "$DAV1D_SOURCE_DIR/meson.build" \
  "$LIBBLURAY_SOURCE_DIR/meson.build" \
  "$LIBUDFREAD_SOURCE_DIR/meson.build"; do
  test -f "$required_path" || {
    echo "error: extracted source is incomplete: $required_path" >&2
    exit 66
  }
done

rm -rf "$LIBBLURAY_SOURCE_DIR/contrib/libudfread"
mkdir -p "$LIBBLURAY_SOURCE_DIR/contrib"
cp -R "$LIBUDFREAD_SOURCE_DIR" "$LIBBLURAY_SOURCE_DIR/contrib/libudfread"

CORE_ROOT="$(npc_core_root)"
CORE_SCRIPT="$CORE_ROOT/scripts/build-ffmpeg-apple.sh"

export NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES="macosx-arm64"
export NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE="base"
export NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE="static"
export NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS="--enable-libdav1d --disable-network"
export NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES=libdav1d
export NSURATOR_PLAYER_CORE_MESON="$MESON_EXECUTABLE"
export NSURATOR_PLAYER_CORE_DEP_PREFIX="$WORK_ROOT/dependencies"
export NSURATOR_PLAYER_CORE_DAV1D_BUILD_DIR="$WORK_ROOT/dav1d-build"
export NSURATOR_PLAYER_CORE_LIBBLURAY_BUILD_DIR="$WORK_ROOT/libbluray-build"
export NSURATOR_PLAYER_CORE_FFMPEG_BUILD_DIR="$WORK_ROOT/ffmpeg-build"
export NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR="$WORK_ROOT/ffmpeg-install"

DAV1D_SOURCE_DIR="$DAV1D_SOURCE_DIR" "$CORE_SCRIPT" --build-dav1d
LIBBLURAY_SOURCE_DIR="$LIBBLURAY_SOURCE_DIR" "$CORE_SCRIPT" --build-libbluray
FFMPEG_SOURCE_DIR="$FFMPEG_SOURCE_DIR" "$CORE_SCRIPT"

ARTIFACT_DIRECTORY_NAME="nsurator-player-core-ffmpeg-macosx-arm64-$ARTIFACT_VERSION"
ARTIFACT_ROOT="$DIST_ROOT/$ARTIFACT_DIRECTORY_NAME"
ARCHIVE_PATH="$DIST_ROOT/$ARTIFACT_DIRECTORY_NAME.tar.gz"
rm -rf "$ARTIFACT_ROOT" "$ARCHIVE_PATH"

NSURATOR_PLAYER_CORE_ARTIFACT_INSTALL_RELATIVE_PATH=install \
NSURATOR_PLAYER_CORE_ARTIFACT_DEP_RELATIVE_PATH=dependencies \
  "$CORE_SCRIPT" --package-artifact-root "$ARTIFACT_ROOT" "$NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR"

LICENSE_ROOT="$ARTIFACT_ROOT/licenses"
mkdir -p "$LICENSE_ROOT"
cp "$FFMPEG_SOURCE_DIR/LICENSE.md" "$LICENSE_ROOT/FFmpeg-LICENSE.md"
cp "$FFMPEG_SOURCE_DIR/COPYING.LGPLv2.1" "$LICENSE_ROOT/FFmpeg-COPYING.LGPLv2.1"
cp "$DAV1D_SOURCE_DIR/COPYING" "$LICENSE_ROOT/dav1d-COPYING"
cp "$LIBBLURAY_SOURCE_DIR/COPYING" "$LICENSE_ROOT/libbluray-COPYING"
cp "$LIBUDFREAD_SOURCE_DIR/COPYING" "$LICENSE_ROOT/libudfread-COPYING"
cp "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" "$ARTIFACT_ROOT/NSURATOR-ARTIFACT-PROVENANCE.json"

(
  cd "$CORE_ROOT"
  eval "$("$CORE_SCRIPT" --print-artifact-env "$ARTIFACT_ROOT" macosx-arm64)"
  runtime_capabilities_json="$(
    swift run nsurator-player-core-macos-smoke --print-ffmpeg-runtime-capabilities
  )"
  export NSURATOR_PLAYER_CORE_FFMPEG_RUNTIME_CAPABILITIES_JSON="$runtime_capabilities_json"
  "$CORE_SCRIPT" --embed-artifact-runtime-capabilities "$ARTIFACT_ROOT"
)
"$CORE_ROOT/scripts/assemble-ffmpeg-artifact-release-packet.py" \
  --artifact-root "$ARTIFACT_ROOT" \
  --provenance "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" \
  --source-archive-root "$SOURCE_ARCHIVE_ROOT"
"$CORE_SCRIPT" --verify-release-artifact-root "$ARTIFACT_ROOT" macosx-arm64

(
  cd "$DIST_ROOT"
  COPYFILE_DISABLE=1 tar -czf "$ARCHIVE_PATH" "$ARTIFACT_DIRECTORY_NAME"
)

printf 'artifactRoot=%s\n' "$ARTIFACT_ROOT"
printf 'archivePath=%s\n' "$ARCHIVE_PATH"
