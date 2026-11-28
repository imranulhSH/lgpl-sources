#!/usr/bin/env bash
# Reproducible local tvOS runtime, using the same locked components as Mac.
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
core_root="$(cd "$script_dir/.." && pwd)"
if [[ "${1:-}" == --help ]]; then
  cat <<'HELP'
Usage: scripts/build-tvos-ffmpeg-runtime.sh [--prepare-only]
Downloads and SHA-verifies the pinned sources in Config/tvos-ffmpeg-sources.json,
then builds device and arm64 simulator static FFmpeg/libbluray/dav1d artifacts.
All sources, patches, build logs and outputs stay under this worktree's .build.
Uses a temporary no-space symlink because FFmpeg configure cannot build in a
path containing spaces. Nothing is installed globally or published.

NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES may select either or both TV slices.
Outputs: .build/tvos-runtime/artifact
This is the Mac-equivalent base + dav1d profile, NOT an all-codecs claim.
Networking remains in the host connectors through npc-hostio custom AVIO.
--prepare-only verifies/downloads sources without compiling.
HELP
  exit 0
fi
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --prepare-only ) ]]; then
  echo 'error: unsupported argument (see --help)' >&2; exit 64
fi
runtime_dir="$core_root/.build/tvos-runtime"
mkdir -p "$runtime_dir"
python3 "$script_dir/prepare-tvos-ffmpeg-sources.py" --lock "$core_root/Config/tvos-ffmpeg-sources.json" --root "$runtime_dir"
if [[ "${1:-}" == --prepare-only ]]; then exit 0; fi
# The symlink is merely an alias: actual data remains in this single worktree.
runtime_key="$(printf '%s' "$runtime_dir" | shasum -a 256 | cut -c 1-12)"
runtime_alias="/tmp/nsurator-tvos-core-$runtime_key"
if [[ -L "$runtime_alias" ]]; then
  [[ "$(readlink "$runtime_alias")" == "$runtime_dir" ]] || { echo 'error: conflicting build alias' >&2; exit 65; }
elif [[ -e "$runtime_alias" ]]; then
  echo 'error: build alias path already exists' >&2; exit 65
else
  ln -s "$runtime_dir" "$runtime_alias"
fi
export NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES="${NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES:-appletvos-arm64 appletvsimulator-arm64}"
for slice in $NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES; do
  case "$slice" in appletvos-arm64|appletvsimulator-arm64) ;; *) echo "error: non-TV slice: $slice" >&2; exit 64 ;; esac
done
export NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE=base
export NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE=static
export NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS='--enable-libdav1d --disable-network'
export NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES=libdav1d
export NSURATOR_PLAYER_CORE_ENABLE_NETWORK_PROTOCOLS=0
export NSURATOR_PLAYER_CORE_DEP_PREFIX="$runtime_alias/dependencies"
export NSURATOR_PLAYER_CORE_DAV1D_BUILD_DIR="$runtime_alias/dav1d-build"
export NSURATOR_PLAYER_CORE_LIBBLURAY_BUILD_DIR="$runtime_alias/libbluray-build"
export NSURATOR_PLAYER_CORE_FFMPEG_BUILD_DIR="$runtime_alias/ffmpeg-build"
export NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR="$runtime_alias/ffmpeg-install"
component_version() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sources"][sys.argv[2]]["version"])' "$core_root/Config/tvos-ffmpeg-sources.json" "$1"; }
export DAV1D_SOURCE_DIR="$runtime_alias/sources/dav1d-$(component_version dav1d)"
export LIBBLURAY_SOURCE_DIR="$runtime_alias/sources/libbluray-$(component_version libbluray)"
export FFMPEG_SOURCE_DIR="$runtime_alias/sources/ffmpeg-$(component_version ffmpeg)"
run_logged() {
  local log_name="$1"; shift
  printf 'Running %s; log: %s\n' "$log_name" "$runtime_dir/$log_name.log"
  if "$@" > "$runtime_dir/$log_name.log" 2>&1; then
    tail -n 3 "$runtime_dir/$log_name.log"
  else
    local build_exit=$?
    tail -n 60 "$runtime_dir/$log_name.log" >&2
    return "$build_exit"
  fi
}
run_logged dav1d-build "$script_dir/build-ffmpeg-apple.sh" --build-dav1d
run_logged libbluray-build "$script_dir/build-ffmpeg-apple.sh" --build-libbluray
run_logged ffmpeg-build "$script_dir/build-ffmpeg-apple.sh"
licenses="$runtime_alias/licenses"
mkdir -p "$licenses"
cp "$FFMPEG_SOURCE_DIR/LICENSE.md" "$licenses/FFmpeg-LICENSE.md"
cp "$FFMPEG_SOURCE_DIR/COPYING.LGPLv2.1" "$licenses/FFmpeg-COPYING.LGPLv2.1"
cp "$DAV1D_SOURCE_DIR/COPYING" "$licenses/dav1d-COPYING"
cp "$LIBBLURAY_SOURCE_DIR/COPYING" "$licenses/libbluray-COPYING"
cp "$runtime_alias/sources/libudfread-$(component_version libudfread)/COPYING" "$licenses/libudfread-COPYING"
export NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_SOURCE_DIR="$licenses"
export NSURATOR_PLAYER_CORE_ARTIFACT_INSTALL_RELATIVE_PATH=install
export NSURATOR_PLAYER_CORE_ARTIFACT_DEP_RELATIVE_PATH=dependencies
run_logged package "$script_dir/build-ffmpeg-apple.sh" --package-artifact-root "$runtime_alias/artifact" "$NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR"
cp "$core_root/Config/tvos-ffmpeg-sources.json" "$runtime_alias/artifact/NSURATOR-ARTIFACT-PROVENANCE.json"
python3 "$script_dir/write-tvos-build-evidence.py" "$core_root" "$runtime_alias/artifact"
run_logged verify "$script_dir/build-ffmpeg-apple.sh" --verify-artifact-root "$runtime_alias/artifact"
printf 'artifactRoot=%s\n' "$runtime_dir/artifact"
printf 'No runtime or Apple TV hardware verification is implied by artifact build verification.\n'
