#!/usr/bin/env bash
# Builds the iPhone/iPad FFmpeg runtime: FFmpeg, libbluray (with libudfread)
# and dav1d, LGPL only, linked into one dynamic
# NsuratorPlayerCoreFFmpegRuntime.framework per slice and joined into
# NsuratorPlayerCoreFFmpegRuntime.xcframework (ios-arm64, ios-arm64-simulator).
#
# Everything comes from Config/nsurator-player-core-ios-runtime.json (sources,
# checksums, configure flags) and the player core's own scripts at the
# revision given with --core-root: build-ffmpeg-apple.sh builds the static
# libraries with the core's patches, package-apple-ffmpeg-runtime-framework.sh
# links each slice. The Mac's artifact 2026.10.09.1 is the same recipe for
# macosx-arm64 (nsurator-macos-native script/build_nsurator_player_core_ffmpeg_artifact.sh).
#
# Usage: scripts/build-ios-player-core-runtime.sh --core-root <player core checkout> \
#          --work-root <new dir, no spaces> [--source-cache <dir>]
# Output: <work-root>/dist/NsuratorPlayerCoreFFmpegRuntime.xcframework plus
#         <work-root>/records (configure lines, framework records, licences).
# Install it with scripts/install-ios-player-core-runtime.sh.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock="$project_root/Config/nsurator-player-core-ios-runtime.json"
core_root="" work_root="" source_cache=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --core-root) core_root="${2:-}"; shift 2 ;;
    --work-root) work_root="${2:-}"; shift 2 ;;
    --source-cache) source_cache="${2:-}"; shift 2 ;;
    *) echo "usage: $0 --core-root <dir> --work-root <dir> [--source-cache <dir>]" >&2; exit 64 ;;
  esac
done
[[ -n "$core_root" && -n "$work_root" ]] || { echo "error: --core-root and --work-root are required" >&2; exit 64; }
[[ "$work_root" != *" "* ]] || { echo "error: --work-root must not contain spaces (FFmpeg's configure)" >&2; exit 64; }
core_root="$(cd "$core_root" && pwd)"
core_script="$core_root/scripts/build-ffmpeg-apple.sh"
packager="$core_root/scripts/package-apple-ffmpeg-runtime-framework.sh"
[[ -x "$core_script" && -x "$packager" ]] || { echo "error: not a player core checkout: $core_root" >&2; exit 66; }

value() { python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); 
for k in sys.argv[2:]: d=d[k]
print(d)' "$lock" "$@"; }

mkdir -p "$work_root"
work_root="$(cd "$work_root" && pwd)"
archives="$work_root/source-archives" sources="$work_root/sources" records="$work_root/records"
mkdir -p "$archives" "$records/configure" "$records/frameworks" "$records/licenses"
rm -rf "$sources"; mkdir -p "$sources"

for key in ffmpeg dav1d libbluray libudfread; do
  name="$(value sources "$key" archiveName)"
  destination="$archives/$name"
  if [[ -n "$source_cache" && -f "$source_cache/$name" ]]; then
    cp "$source_cache/$name" "$destination"
  elif [[ ! -f "$destination" ]]; then
    curl -fsSL "$(value sources "$key" url)" -o "$destination.download"
    mv "$destination.download" "$destination"
  fi
  actual="$(shasum -a 256 "$destination" | awk '{print $1}')"
  [[ "$actual" == "$(value sources "$key" sha256)" ]] || { echo "error: checksum mismatch for $name: $actual" >&2; exit 65; }
  tar -xf "$destination" -C "$sources"
done
ffmpeg_source="$sources/ffmpeg-$(value sources ffmpeg version)"
dav1d_source="$sources/dav1d-$(value sources dav1d version)"
libbluray_source="$sources/libbluray-$(value sources libbluray version)"
libudfread_source="$sources/libudfread-$(value sources libudfread version)"
rm -rf "$libbluray_source/contrib/libudfread"
mkdir -p "$libbluray_source/contrib"
cp -R "$libudfread_source" "$libbluray_source/contrib/libudfread"

minimum_os="$(value minimumIOSVersion)"
# A caller's environment must not change the recipe.
unset NSURATOR_PLAYER_CORE_ENABLE_NETWORK_PROTOCOLS NSURATOR_PLAYER_CORE_DEP_CFLAGS NSURATOR_PLAYER_CORE_DEP_LDFLAGS
unset NSURATOR_PLAYER_CORE_FFMPEG_PREFIX PKG_CONFIG_PATH PKG_CONFIG_LIBDIR
export NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES="$(value slices | tr -d "[]',")"
export NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE="$(value linkProfile)"
export NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS="$(value extraFFmpegConfigureFlags)"
export NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES="$(value extraRuntimeLibraries)"
export NSURATOR_PLAYER_CORE_DEP_PREFIX="$work_root/dependencies"
export NSURATOR_PLAYER_CORE_DAV1D_BUILD_DIR="$work_root/dav1d-build"
export NSURATOR_PLAYER_CORE_LIBBLURAY_BUILD_DIR="$work_root/libbluray-build"
export NSURATOR_PLAYER_CORE_FFMPEG_BUILD_DIR="$work_root/ffmpeg-build"
export NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR="$work_root/ffmpeg-install"

DAV1D_SOURCE_DIR="$dav1d_source" "$core_script" --build-dav1d
LIBBLURAY_SOURCE_DIR="$libbluray_source" "$core_script" --build-libbluray
FFMPEG_SOURCE_DIR="$ffmpeg_source" "$core_script"

frameworks=()
for slice in $NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES; do
  case "$slice" in
    iphoneos-arm64) sdk=iphoneos; triple="arm64-apple-ios${minimum_os}" ;;
    iphonesimulator-arm64) sdk=iphonesimulator; triple="arm64-apple-ios${minimum_os}-simulator" ;;
    *) echo "error: unexpected slice $slice" >&2; exit 65 ;;
  esac
  "$packager" --build --sdk "$sdk" --target-triple "$triple" \
    --ffmpeg-prefix "$NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR/$slice" \
    --dependency-prefix "$NSURATOR_PLAYER_CORE_DEP_PREFIX/$slice" \
    --output-dir "$work_root/frameworks/$slice" --record-root "$work_root"
  "$packager" --verify "$work_root/frameworks/$slice/NsuratorPlayerCoreFFmpegRuntime.framework" --minimum-os "$minimum_os"
  cp "$work_root/frameworks/$slice/FRAMEWORK-RECORD.json" "$records/frameworks/$slice-FRAMEWORK-RECORD.json"
  cp "$NSURATOR_PLAYER_CORE_FFMPEG_BUILD_DIR/$slice/ffbuild/config.mak" "$records/configure/ffmpeg-$slice-config.mak"
  sed -n 's/^FFMPEG_CONFIGURATION=//p' "$records/configure/ffmpeg-$slice-config.mak" \
    | sed "s#$work_root#\$WORK#g" > "$records/configure/ffmpeg-$slice-configure.txt"
  frameworks+=(-framework "$work_root/frameworks/$slice/NsuratorPlayerCoreFFmpegRuntime.framework")
done

rm -rf "$work_root/dist"; mkdir -p "$work_root/dist"
xcodebuild -create-xcframework "${frameworks[@]}" -output "$work_root/dist/NsuratorPlayerCoreFFmpegRuntime.xcframework"
# One header tree for the C shim; the slices' public headers are identical.
mkdir -p "$work_root/dist/include"
cp -R "$NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR/iphoneos-arm64/include/." "$work_root/dist/include/"
cp -R "$NSURATOR_PLAYER_CORE_DEP_PREFIX/iphoneos-arm64/include/libbluray" "$work_root/dist/include/"
for slice in iphonesimulator-arm64; do
  diff -r "$NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR/iphoneos-arm64/include" "$NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR/$slice/include" >/dev/null \
    || { echo "error: FFmpeg headers differ between slices" >&2; exit 65; }
done

cp "$ffmpeg_source/LICENSE.md" "$records/licenses/FFmpeg-LICENSE.md"
cp "$ffmpeg_source/COPYING.LGPLv2.1" "$records/licenses/FFmpeg-COPYING.LGPLv2.1"
cp "$dav1d_source/COPYING" "$records/licenses/dav1d-COPYING"
cp "$libbluray_source/COPYING" "$records/licenses/libbluray-COPYING"
cp "$libudfread_source/COPYING" "$records/licenses/libudfread-COPYING"
cp "$lock" "$records/nsurator-player-core-ios-runtime.json"
{
  printf 'coreRevision=%s\n' "$(git -C "$core_root" rev-parse HEAD)"
  printf 'coreDirty=%s\n' "$(git -C "$core_root" status --porcelain -- scripts | wc -l | tr -d ' ')"
  xcodebuild -version | tr '\n' ' '; echo
  xcrun --sdk iphoneos clang --version | head -1
  printf 'meson=%s\n' "$(${NSURATOR_PLAYER_CORE_MESON:-meson} --version)"
} > "$records/toolchain.txt"
echo "xcframework=$work_root/dist/NsuratorPlayerCoreFFmpegRuntime.xcframework"
