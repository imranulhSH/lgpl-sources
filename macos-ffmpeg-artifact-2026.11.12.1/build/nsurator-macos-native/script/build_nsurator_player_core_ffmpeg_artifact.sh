#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=nsurator_player_core_artifact_common.sh
source "$SCRIPT_DIR/nsurator_player_core_artifact_common.sh"

DRY_RUN=false
REPACKAGE_FROM_ARTIFACT=""
SOURCE_CACHE=""
WORK_ROOT=""
DIST_ROOT="$NSURATOR_NATIVE_ROOT/.build/nsurator-player-core-artifacts/dist"

usage() {
  cat <<'USAGE'
usage: script/build_nsurator_player_core_ffmpeg_artifact.sh [options]

Options:
  --dry-run
  --repackage-from-artifact <installed-artifact-root>
      Build no FFmpeg: take the static libraries of the artifact the source
      lock's baseArtifact names (checked against its manifest and archive
      checksums), package them as the framework-mode artifact, and assemble
      its release packet.
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
    --repackage-from-artifact)
      REPACKAGE_FROM_ARTIFACT="${2:-}"
      shift 2
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

# Repackages the static libraries of an earlier artifact as this lock's
# framework-mode artifact. The libraries stay byte for byte the ones the base
# artifact shipped (and whose corresponding source is already published), so
# the only new binary is the runtime framework built from them.
repackage_from_artifact() {
  local base_root="$1"
  [[ -d "$base_root" ]] || { echo "error: base artifact root does not exist: $base_root" >&2; exit 66; }
  base_root="$(cd "$base_root" && pwd -P)"
  [[ "$LINK_MODE" == "framework" ]] || {
    echo "error: --repackage-from-artifact builds framework-mode artifacts; the source lock says $LINK_MODE" >&2
    exit 64
  }

  local base_manifest="$base_root/nsurator-player-core-ffmpeg-apple-manifest.json"
  local expected_manifest_sha actual_manifest_sha
  expected_manifest_sha="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" baseArtifact.manifestSHA256)"
  actual_manifest_sha="$(npc_sha256 "$base_manifest")"
  [[ "$actual_manifest_sha" == "$expected_manifest_sha" ]] || {
    echo "error: base artifact manifest checksum mismatch: expected $expected_manifest_sha, found $actual_manifest_sha" >&2
    exit 65
  }
  local library_count index relative_path expected_sha actual_sha
  library_count="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" baseArtifact.staticLibraries)"
  [[ "$library_count" -gt 0 ]] || { echo "error: source lock baseArtifact lists no static libraries" >&2; exit 65; }
  for ((index = 0; index < library_count; index += 1)); do
    relative_path="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" "baseArtifact.staticLibraries.$index.relativePath")"
    expected_sha="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" "baseArtifact.staticLibraries.$index.sha256")"
    [[ "$relative_path" != /* && "$relative_path" != *".."* ]] || { echo "error: unsafe library path: $relative_path" >&2; exit 65; }
    actual_sha="$(npc_sha256 "$base_root/$relative_path")"
    [[ "$actual_sha" == "$expected_sha" ]] || {
      echo "error: base artifact library checksum mismatch for $relative_path: expected $expected_sha, found $actual_sha" >&2
      exit 65
    }
  done
  local found_libraries
  found_libraries="$(/usr/bin/find "$base_root/install" "$base_root/dependencies" -type f -name '*.a' | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
  [[ "$found_libraries" == "$library_count" ]] || {
    echo "error: base artifact carries $found_libraries static libraries, the lock pins $library_count" >&2
    exit 65
  }

  local core_root core_script
  core_root="$(npc_core_root)"
  core_script="$core_root/scripts/build-ffmpeg-apple.sh"

  if [[ -z "$WORK_ROOT" ]]; then
    WORK_ROOT="/tmp/nsurator-npc-artifact-repack-${ARTIFACT_VERSION//./}"
  fi
  mkdir -p "$WORK_ROOT" "$DIST_ROOT"
  # Work on a copy: the installed artifact's xcconfig is derived per install
  # location (the installer rewrites it), so the copy gets its own before the
  # base artifact is verified, and the cache stays untouched.
  local base_copy="$WORK_ROOT/base-artifact"
  rm -rf "$base_copy"
  /usr/bin/ditto "$base_root" "$base_copy"
  rm -f "$base_copy/NsuratorPlayerCoreFFmpeg.xcconfig"
  for ((index = 0; index < library_count; index += 1)); do
    relative_path="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" "baseArtifact.staticLibraries.$index.relativePath")"
    expected_sha="$(npc_json_value "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" "baseArtifact.staticLibraries.$index.sha256")"
    [[ "$(npc_sha256 "$base_copy/$relative_path")" == "$expected_sha" ]] || {
      echo "error: copied base library differs from the lock: $relative_path" >&2
      exit 65
    }
  done
  base_root="$base_copy"
  NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE=base \
  NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE=static \
  NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES=libdav1d \
    "$core_script" --print-artifact-xcconfig-root "$base_root" > "$base_root/NsuratorPlayerCoreFFmpeg.xcconfig"
  NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE=base \
  NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE=static \
  NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES=libdav1d \
    "$core_script" --verify-artifact-root "$base_root" "$SLICE_NAME" >&2
  local artifact_directory_name="nsurator-player-core-ffmpeg-macosx-arm64-$ARTIFACT_VERSION"
  local artifact_root="$DIST_ROOT/$artifact_directory_name"
  local archive_path="$DIST_ROOT/$artifact_directory_name.tar.gz"
  rm -rf "$artifact_root" "$archive_path"

  export NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES="$SLICE_NAME"
  export NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE="$LINK_PROFILE"
  export NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE="$LINK_MODE"
  export NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS="--enable-libdav1d --disable-network"
  export NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES=libdav1d
  export NSURATOR_PLAYER_CORE_DEP_PREFIX="$base_root/dependencies"
  # The base artifact's licenses/ and distribution/ sit beside its install/
  # and are carried over; the release packet below replaces distribution/.
  NSURATOR_PLAYER_CORE_ARTIFACT_INSTALL_RELATIVE_PATH=install \
  NSURATOR_PLAYER_CORE_ARTIFACT_DEP_RELATIVE_PATH=dependencies \
    "$core_script" --package-artifact-root "$artifact_root" "$base_root/install"
  unset NSURATOR_PLAYER_CORE_DEP_PREFIX
  cp "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" "$artifact_root/NSURATOR-ARTIFACT-PROVENANCE.json"

  # The first real link and load of the framework: the core's smoke tool,
  # linked through Package.swift's framework mode, reports what the linked
  # libraries can do. It must be exactly what the static base artifact reported.
  local capabilities_json
  capabilities_json="$(
    cd "$core_root"
    eval "$("$core_script" --print-artifact-env "$artifact_root" "$SLICE_NAME")"
    swift run --scratch-path "$WORK_ROOT/core-smoke-spm" \
      nsurator-player-core-macos-smoke --print-ffmpeg-runtime-capabilities
  )"
  python3 -I - "$base_manifest" "$capabilities_json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    base = json.load(handle).get("runtimeCapabilities")
measured = json.loads(sys.argv[2])
if base != measured:
    keys = sorted(set(base or {}) | set(measured))
    changed = [key for key in keys if (base or {}).get(key) != measured.get(key)]
    sys.exit("error: framework runtime capabilities differ from the base artifact: " + ", ".join(changed))
PY
  NSURATOR_PLAYER_CORE_FFMPEG_RUNTIME_CAPABILITIES_JSON="$capabilities_json" \
    "$core_script" --embed-artifact-runtime-capabilities "$artifact_root"

  "$core_root/scripts/assemble-ffmpeg-artifact-release-packet.py" \
    --artifact-root "$artifact_root" \
    --provenance "$NSURATOR_NATIVE_NPC_SOURCE_LOCK" \
    --source-archive-root "$base_root/distribution/source-offer/sources"
  "$core_script" --verify-release-artifact-root "$artifact_root" "$SLICE_NAME"

  (
    cd "$DIST_ROOT"
    COPYFILE_DISABLE=1 tar -czf "$archive_path" "$artifact_directory_name"
  )

  printf 'artifactRoot=%s\n' "$artifact_root"
  printf 'archivePath=%s\n' "$archive_path"
  printf 'archiveSHA256=%s\n' "$(npc_sha256 "$archive_path")"
  printf 'manifestSHA256=%s\n' "$(npc_sha256 "$artifact_root/nsurator-player-core-ffmpeg-apple-manifest.json")"
}

if [[ -n "$REPACKAGE_FROM_ARTIFACT" ]]; then
  repackage_from_artifact "$REPACKAGE_FROM_ARTIFACT"
  exit 0
fi

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
export NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE="$LINK_MODE"
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
