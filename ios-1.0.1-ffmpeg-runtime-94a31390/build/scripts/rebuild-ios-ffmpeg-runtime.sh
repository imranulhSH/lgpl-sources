#!/usr/bin/env bash
set -euo pipefail

# Produces only an isolated candidate. Never replaces the checked-in runtime.
if [[ $# -ne 1 || "$1" != /* || "$1" == *" "* || -e "$1" ]]; then
  printf 'Usage: %s <new-absolute-no-space-build-directory>\n' "$0" >&2
  exit 64
fi
task_root="$1"
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
core="$project_root/Packages/vision-player-core"
mkdir -p "$task_root/sources" "$task_root/evidence"
curl --fail --location --retry 2 https://ffmpeg.org/releases/ffmpeg-8.1.tar.xz \
  --output "$task_root/sources/ffmpeg-8.1.tar.xz"
python3 - "$task_root/sources/ffmpeg-8.1.tar.xz" <<'PY'
import hashlib, sys
from pathlib import Path
assert hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest() == "b072aed6871998cce9b36e7774033105ca29e33632be5b6347f3206898e0756a", "Unreviewed FFmpeg source hash"
PY
tar -xf "$task_root/sources/ffmpeg-8.1.tar.xz" -C "$task_root/sources"
curl --fail --location --retry 2 https://download.videolan.org/pub/videolan/dav1d/1.5.4/dav1d-1.5.4.tar.xz \
  --output "$task_root/sources/dav1d-1.5.4.tar.xz"
python3 - "$task_root/sources/dav1d-1.5.4.tar.xz" <<'PY'
import hashlib, sys
from pathlib import Path
assert hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest() == "686616b7c69eb88d44459391ab25cac13b6647a3b288835c5784e71c1514a5c5", "Unreviewed dav1d source hash"
PY
tar -xf "$task_root/sources/dav1d-1.5.4.tar.xz" -C "$task_root/sources"
git clone --filter=blob:none --no-checkout https://code.videolan.org/videolan/libbluray.git "$task_root/sources/libbluray"
git -C "$task_root/sources/libbluray" checkout --detach 7d94f2660af5bfc16015291a03539329135c18f1
git -C "$task_root/sources/libbluray" submodule update --init --recursive
[[ "$(git -C "$task_root/sources/libbluray/contrib/libudfread" rev-parse HEAD)" == 139a2194525f2745b98a98e4d8fa627d07440176 ]]

export FFMPEG_SOURCE_DIR="$task_root/sources/ffmpeg-8.1"
export LIBBLURAY_SOURCE_DIR="$task_root/sources/libbluray"
export DAV1D_SOURCE_DIR="$task_root/sources/dav1d-1.5.4"
export VISION_PLAYER_CORE_DAV1D_BUILD_DIR="$task_root/build/dav1d"
export VISION_PLAYER_CORE_FFMPEG_BUILD_DIR="$task_root/build/ffmpeg"
export VISION_PLAYER_CORE_FFMPEG_INSTALL_DIR="$task_root/install/ffmpeg"
export VISION_PLAYER_CORE_LIBBLURAY_BUILD_DIR="$task_root/build/libbluray"
export VISION_PLAYER_CORE_DEP_PREFIX="$task_root/install/dependencies"
export VISION_PLAYER_CORE_APPLE_BUILD_SLICES="iphoneos-arm64 iphonesimulator-arm64 macosx-arm64"
export VISION_PLAYER_CORE_FFMPEG_LINK_PROFILE=base
# A caller's optional network/dependency profile must not alter this recipe.
unset VISION_PLAYER_CORE_ENABLE_NETWORK_PROTOCOLS VISION_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS
unset VISION_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES VISION_PLAYER_CORE_DEP_CFLAGS VISION_PLAYER_CORE_DEP_LDFLAGS
unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR VISION_PLAYER_CORE_FFMPEG_PREFIX
"$core/scripts/build-ffmpeg-apple.sh" --build-libbluray 2>&1 | tee "$task_root/evidence/libbluray-build.log"
"$core/scripts/build-ffmpeg-apple.sh" --build-dav1d 2>&1 | tee "$task_root/evidence/dav1d-build.log"
export VISION_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS=--enable-libdav1d
"$core/scripts/build-ffmpeg-apple.sh" 2>&1 | tee "$task_root/evidence/ffmpeg-build.log"
shasum -a 256 "$core"/scripts/patches/ffmpeg-*.patch > "$task_root/evidence/ffmpeg-patch-hashes.txt"
git -C "$LIBBLURAY_SOURCE_DIR" diff --binary > "$task_root/evidence/libbluray.patch"
for slice in iphoneos-arm64 iphonesimulator-arm64 macosx-arm64; do
  cp "$task_root/build/ffmpeg/$slice/ffbuild/config.mak" "$task_root/evidence/ffmpeg-$slice-config.mak"
done
xcodebuild -version > "$task_root/evidence/xcode-version.txt"
cp "$FFMPEG_SOURCE_DIR/COPYING.LGPLv2.1" "$task_root/evidence/ffmpeg-COPYING.LGPLv2.1"
cp "$LIBBLURAY_SOURCE_DIR/COPYING" "$task_root/evidence/libbluray-COPYING"
cp "$LIBBLURAY_SOURCE_DIR/contrib/libudfread/COPYING" "$task_root/evidence/libudfread-COPYING"
cp "$DAV1D_SOURCE_DIR/COPYING" "$task_root/evidence/dav1d-COPYING"
python3 "$project_root/scripts/stage-ios-ffmpeg-candidate.py" "$task_root/install" "$task_root/candidate"
printf 'Review sources/configuration/licenses and run real paired HostIO tests before publishing %s/candidate.\n' "$task_root"
