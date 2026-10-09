#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  "${script_dir}/build-ffmpeg-visionos.sh" "$@" |
    sed \
      -e 's#scripts/build-ffmpeg-visionos.sh#scripts/build-ffmpeg-apple.sh#g' \
      -e 's#\.build/ffmpeg-visionos#\.build/ffmpeg-apple#g' \
      -e 's#\.build/dav1d-visionos#\.build/dav1d-apple#g' \
      -e 's#\.build/libbluray-visionos#\.build/libbluray-apple#g' \
      -e 's#\.build/libdvdread-visionos#\.build/libdvdread-apple#g' \
      -e 's#\.build/libdvdnav-visionos#\.build/libdvdnav-apple#g' \
      -e 's#\.build/libdvd-visionos#\.build/libdvd-apple#g' \
      -e 's#The default build produces macosx-arm64, iphoneos-arm64,#The default build produces macosx-arm64 FFmpeg installs by default; set#g' \
      -e 's#iphonesimulator-arm64, xros-arm64, and xrsimulator-arm64 FFmpeg installs#VISION_PLAYER_CORE_APPLE_BUILD_SLICES for iphoneos-arm64, iphonesimulator-arm64, xros-arm64, and xrsimulator-arm64#g' \
      -e 's#Build/root modes expect slice subdirectories named#Build/root modes default to slice subdirectories named#g' \
      -e 's#macosx-arm64, iphoneos-arm64,#macosx-arm64 by default; include iphoneos-arm64,#g' \
      -e 's#and xrsimulator-arm64; single-prefix print#and xrsimulator-arm64 only when explicitly requested; single-prefix print#g' \
      -e 's#Defaults to all Apple slices\. Use#Defaults to macosx-arm64. Set#g' \
      -e 's#emits SDK-conditional settings for all Apple slices#emits SDK-conditional settings for the selected Apple slices#g'
  exit "${PIPESTATUS[0]}"
fi

package_root="$(cd "${script_dir}/.." && pwd)"
: "${VISION_PLAYER_CORE_FFMPEG_BUILD_DIR:=${package_root}/.build/ffmpeg-apple}"
: "${VISION_PLAYER_CORE_FFMPEG_INSTALL_DIR:=${VISION_PLAYER_CORE_FFMPEG_BUILD_DIR}/install}"
: "${VISION_PLAYER_CORE_DAV1D_BUILD_DIR:=${package_root}/.build/dav1d-apple}"
: "${VISION_PLAYER_CORE_DAV1D_INSTALL_DIR:=${VISION_PLAYER_CORE_DAV1D_BUILD_DIR}/install}"
: "${VISION_PLAYER_CORE_LIBBLURAY_BUILD_DIR:=${package_root}/.build/libbluray-apple}"
: "${VISION_PLAYER_CORE_LIBBLURAY_INSTALL_DIR:=${VISION_PLAYER_CORE_LIBBLURAY_BUILD_DIR}/install}"
: "${VISION_PLAYER_CORE_LIBDVDREAD_BUILD_DIR:=${package_root}/.build/libdvdread-apple}"
: "${VISION_PLAYER_CORE_LIBDVDNAV_BUILD_DIR:=${package_root}/.build/libdvdnav-apple}"
: "${VISION_PLAYER_CORE_LIBDVD_INSTALL_DIR:=${package_root}/.build/libdvd-apple/install}"
: "${VISION_PLAYER_CORE_APPLE_BUILD_SLICES:=macosx-arm64}"

export VISION_PLAYER_CORE_FFMPEG_BUILD_DIR
export VISION_PLAYER_CORE_FFMPEG_INSTALL_DIR
export VISION_PLAYER_CORE_DAV1D_BUILD_DIR
export VISION_PLAYER_CORE_DAV1D_INSTALL_DIR
export VISION_PLAYER_CORE_LIBBLURAY_BUILD_DIR
export VISION_PLAYER_CORE_LIBBLURAY_INSTALL_DIR
export VISION_PLAYER_CORE_LIBDVDREAD_BUILD_DIR
export VISION_PLAYER_CORE_LIBDVDNAV_BUILD_DIR
export VISION_PLAYER_CORE_LIBDVD_INSTALL_DIR
export VISION_PLAYER_CORE_APPLE_BUILD_SLICES
export VISION_PLAYER_CORE_FFMPEG_BUILD_SCRIPT_NAME="${VISION_PLAYER_CORE_FFMPEG_BUILD_SCRIPT_NAME:-scripts/build-ffmpeg-apple.sh}"
exec "${script_dir}/build-ffmpeg-visionos.sh" "$@"
