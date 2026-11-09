#!/usr/bin/env bash
set -euo pipefail

build_script_name="${NSURATOR_PLAYER_CORE_FFMPEG_BUILD_SCRIPT_NAME:-scripts/build-ffmpeg-visionos.sh}"
artifact_xcconfig_root_build_setting="NSURATOR_PLAYER_CORE_FFMPEG_ARTIFACT_ROOT"

usage() {
  cat <<'USAGE'
Usage:
  scripts/build-ffmpeg-visionos.sh [--dry-run]
  scripts/build-ffmpeg-visionos.sh --build-dav1d [--dry-run]
  scripts/build-ffmpeg-visionos.sh --build-libbluray [--dry-run]
  scripts/build-ffmpeg-visionos.sh --build-libdvdread [--dry-run]
  scripts/build-ffmpeg-visionos.sh --build-libdvdnav [--dry-run]
  scripts/build-ffmpeg-visionos.sh --print-swiftpm-flags <install-prefix>
  scripts/build-ffmpeg-visionos.sh --print-artifact-swiftpm-flags <artifact-root> <slice-name>
  scripts/build-ffmpeg-visionos.sh --print-artifact-env <artifact-root> <slice-name>
  scripts/build-ffmpeg-visionos.sh --print-xcconfig <install-prefix>
  scripts/build-ffmpeg-visionos.sh --print-xcconfig-root <install-root>
  scripts/build-ffmpeg-visionos.sh --print-artifact-xcconfig-root <artifact-root>
  scripts/build-ffmpeg-visionos.sh --print-artifact-manifest-root <install-root>
  scripts/build-ffmpeg-visionos.sh --package-artifact-root <artifact-root> <install-root>
  scripts/build-ffmpeg-visionos.sh --embed-artifact-runtime-capabilities <artifact-root>
  scripts/build-ffmpeg-visionos.sh --print-no-space-build-env <root>
  scripts/build-ffmpeg-visionos.sh --prepare-no-space-build-env <root>
  scripts/build-ffmpeg-visionos.sh --verify-install <install-prefix>
  scripts/build-ffmpeg-visionos.sh --verify-install-root <install-root>
  scripts/build-ffmpeg-visionos.sh --verify-artifact-root <artifact-root> [slice-name]...
  scripts/build-ffmpeg-visionos.sh --verify-release-artifact-root <artifact-root> [slice-name]...

SwiftPM link modes (NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE):
  search      -L/-l flags against the install prefixes (the default).
  static      explicit .a archive paths; the libraries end up inside the app executable.
  framework   one dynamic NsuratorPlayerCoreFFmpegRuntime.framework per macOS slice,
              packaged from the static archives by
              scripts/package-apple-ffmpeg-runtime-framework.sh. Packaging an
              artifact root builds it under frameworks/<slice>/, --print-artifact-env
              exports NSURATOR_PLAYER_CORE_FFMPEG_FRAMEWORK_DIR, and Package.swift links
              the framework instead of the archives, so the app loads FFmpeg from
              Contents/Frameworks and a user can replace it.

Environment:
  FFMPEG_SOURCE_DIR                         Required for FFmpeg builds.
  DAV1D_SOURCE_DIR                          Required for --build-dav1d.
  LIBBLURAY_SOURCE_DIR                      Required for --build-libbluray.
  LIBDVDREAD_SOURCE_DIR                     Required for --build-libdvdread.
  LIBDVDNAV_SOURCE_DIR                      Required for --build-libdvdnav.
  NSURATOR_PLAYER_CORE_FFMPEG_BUILD_DIR       Defaults to .build/ffmpeg-visionos
  NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR     Defaults to .build/ffmpeg-visionos/install
  NSURATOR_PLAYER_CORE_DAV1D_BUILD_DIR        Defaults to .build/dav1d-visionos
  NSURATOR_PLAYER_CORE_DAV1D_INSTALL_DIR      Defaults to .build/dav1d-visionos/install
  NSURATOR_PLAYER_CORE_LIBBLURAY_BUILD_DIR    Defaults to .build/libbluray-visionos
  NSURATOR_PLAYER_CORE_LIBBLURAY_INSTALL_DIR  Defaults to .build/libbluray-visionos/install
  NSURATOR_PLAYER_CORE_LIBDVDREAD_BUILD_DIR   Defaults to .build/libdvdread-visionos
  NSURATOR_PLAYER_CORE_LIBDVDNAV_BUILD_DIR    Defaults to .build/libdvdnav-visionos
  NSURATOR_PLAYER_CORE_LIBDVD_INSTALL_DIR     Shared libdvdread/libdvdnav install root;
                                            defaults to .build/libdvd-visionos/install.
  NSURATOR_PLAYER_CORE_DEP_PREFIX             Optional dependency prefix for libbluray, libdvdnav,
                                            libdvdread, dav1d, and friends.
                                            Build/root modes expect slice subdirectories named
                                            macosx-arm64, iphoneos-arm64,
                                            iphonesimulator-arm64, xros-arm64,
                                            and xrsimulator-arm64; single-prefix print
                                            and verify modes use this value directly.
  NSURATOR_PLAYER_CORE_DEP_CFLAGS             Optional additional dependency C flags.
  NSURATOR_PLAYER_CORE_DEP_LDFLAGS            Optional additional dependency linker flags.
  NSURATOR_PLAYER_CORE_PKG_CONFIG             Optional pkg-config executable for FFmpeg configure.
  NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS
                                            Optional whitespace-separated flags appended to FFmpeg configure.
  NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES
                                            Optional whitespace-separated runtime library names written to
                                            artifact manifests for extra FFmpeg configure flags.
  NSURATOR_PLAYER_CORE_MESON                  Optional meson executable for --build-dav1d
                                            and libbluray/libdvdread/libdvdnav builds.
  NSURATOR_PLAYER_CORE_EXTRA_SWIFTPM_FLAGS    Optional extra flags appended verbatim by
                                            --print-swiftpm-flags for transitive static deps.
  NSURATOR_PLAYER_CORE_FFMPEG_STATIC_LINK_SEARCH_DIRS
                                            Colon-separated library directories searched when
                                            static pkg-config output omits -L for transitive deps.
  NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE    base (default) or full. base is the LGPL build: libav
                                            plus libbluray, without the optional decoder libraries.
                                            full adds dav1d, libdvdnav, libdvdread, and the modern
                                            video decoders; libdvdnav, libdvdread, and libdavs2 are
                                            GPL in FFmpeg, so full only configures with --enable-gpl
                                            and its binaries are GPL.
  NSURATOR_PLAYER_CORE_EXTRA_XCCONFIG_LDFLAGS Optional extra linker flags appended verbatim by
                                            --print-xcconfig for transitive static deps.
  NSURATOR_PLAYER_CORE_ENABLE_NETWORK_PROTOCOLS
                                            Set to 1 to configure optional SMB/SFTP/NFS/SRT/RTMP deps,
                                            built-in FFmpeg network protocols, and TLS.
  NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES     Optional whitespace-separated slice names for build/root
                                            modes. Defaults to all Apple slices. Use
                                            "macosx-arm64 iphoneos-arm64 iphonesimulator-arm64"
                                            for the iOS/macOS-first artifact set. TV slices:
                                            "appletvos-arm64 appletvsimulator-arm64".
  NSURATOR_PLAYER_CORE_ARTIFACT_INSTALL_RELATIVE_PATH
                                            Optional artifact-root-relative FFmpeg install path
                                            written into --print-artifact-manifest-root JSON.
  NSURATOR_PLAYER_CORE_ARTIFACT_DEP_RELATIVE_PATH
                                            Optional artifact-root-relative dependency path
                                            written into --print-artifact-manifest-root JSON.
  NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_SOURCE_DIR
                                            Optional directory copied into an artifact by
                                            --package-artifact-root. Name files
                                            <component>-<document> so release manifests can
                                            attribute each exact license text. When unset and
                                            the install root is an artifact's install subtree,
                                            its sibling licenses directory is preserved.
  NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_RELATIVE_PATH
                                            Optional artifact-root-relative license directory;
                                            defaults to licenses.
  NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_ROOT   Optional license directory scanned by
                                            --print-artifact-manifest-root. Packaging and
                                            capability embedding set this automatically.
  NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_SOURCE_DIR
                                            Optional distribution review directory copied by
                                            --package-artifact-root. Put nonempty files under
                                            attribution/, source-offer/, relink-instructions/,
                                            or relink-materials-manifest/. When unset and the
                                            install root is an artifact's install subtree, its
                                            sibling distribution directory is preserved.
  NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_RELATIVE_PATH
                                            Optional artifact-root-relative review directory;
                                            defaults to distribution.
  NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_ROOT
                                            Optional review directory scanned by
                                            --print-artifact-manifest-root. Packaging and
                                            capability embedding set this automatically.
  NSURATOR_PLAYER_CORE_FFMPEG_FRAMEWORK_DIR   Directory holding NsuratorPlayerCoreFFmpegRuntime.framework;
                                            required by --print-swiftpm-flags in framework mode.
  NSURATOR_PLAYER_CORE_ARTIFACT_FRAMEWORK_RELATIVE_PATH
                                            Optional artifact-root-relative directory for framework-mode
                                            runtime frameworks; defaults to frameworks.
  NSURATOR_PLAYER_CORE_FFMPEG_RUNTIME_CAPABILITIES_JSON
                                            Optional JSON object embedded as runtimeCapabilities in
                                            --print-artifact-manifest-root output.

The default build produces macosx-arm64, iphoneos-arm64,
iphonesimulator-arm64, xros-arm64, and xrsimulator-arm64 FFmpeg installs
that can be linked into NsuratorPlayerCoreFFmpegShim with the printed SwiftPM
flags or included in an Apple platform Xcode app target with the printed xcconfig.
Before configure, the build applies repository-maintained FFmpeg source patches
idempotently and fails closed when the caller source is incompatible.
Build libbluray, libdvdnav, libdvdread, dav1d, and other dependencies for the same SDK/target first and point
NSURATOR_PLAYER_CORE_DEP_PREFIX at the dependency root for multi-slice build/root
modes, or at one dependency prefix for single-prefix print and verify modes.
The --build-dav1d mode builds dav1d into NSURATOR_PLAYER_CORE_DEP_PREFIX when set,
or NSURATOR_PLAYER_CORE_DAV1D_INSTALL_DIR otherwise.
The --build-libbluray mode builds static libbluray into NSURATOR_PLAYER_CORE_DEP_PREFIX
when set, or NSURATOR_PLAYER_CORE_LIBBLURAY_INSTALL_DIR otherwise.
The libbluray build applies the repository fail-closed patch that disables
runtime loading of libaacs, libbdplus, and libmmbd; protected Blu-ray
decryption is not bundled or enabled.
The --build-libdvdread and --build-libdvdnav modes build static clear-disc DVD
dependencies into NSURATOR_PLAYER_CORE_DEP_PREFIX when set, or the shared
NSURATOR_PLAYER_CORE_LIBDVD_INSTALL_DIR otherwise. Build libdvdread first.
The libdvdread build applies the repository fail-closed patch that disables
runtime loading of libdvdcss; encrypted DVD decryption is not bundled or enabled.
For app targets that build both device and simulator, --print-xcconfig-root
emits SDK-conditional settings for all Apple slices.
USAGE
}

quote() {
  printf '%q' "$1"
}

join_quoted() {
  local first=1
  for value in "$@"; do
    if [[ $first -eq 0 ]]; then
      printf ' '
    fi
    first=0
    quote "$value"
  done
}

network_protocols_enabled() {
  case "${NSURATOR_PLAYER_CORE_ENABLE_NETWORK_PROTOCOLS:-0}" in
    1|true|TRUE|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

apple_framework_swiftpm_flags() {
  printf '%s' "-Xlinker -framework -Xlinker CoreFoundation -Xlinker -framework -Xlinker CoreMedia -Xlinker -framework -Xlinker CoreVideo -Xlinker -framework -Xlinker AudioToolbox -Xlinker -framework -Xlinker VideoToolbox"
}

apple_framework_xcconfig_flags() {
  printf '%s' "-framework CoreFoundation -framework CoreMedia -framework CoreVideo -framework AudioToolbox -framework VideoToolbox"
}

apple_build_slices=(
  "macosx-arm64|macosx|arm64-apple-macos14.0|MACOS|sdk=macosx*"
  "iphoneos-arm64|iphoneos|arm64-apple-ios17.0|IOS|sdk=iphoneos*"
  "iphonesimulator-arm64|iphonesimulator|arm64-apple-ios17.0-simulator|IOSSIMULATOR|sdk=iphonesimulator*"
  "appletvos-arm64|appletvos|arm64-apple-tvos17.0|TVOS|sdk=appletvos*"
  "appletvsimulator-arm64|appletvsimulator|arm64-apple-tvos17.0-simulator|TVOSSIMULATOR|sdk=appletvsimulator*"
  "maccatalyst-arm64|maccatalyst|arm64-apple-ios17.0-macabi|MACCATALYST|sdk=macosx*"
  "xros-arm64|xros|arm64-apple-xros1.0|VISIONOS|sdk=xros*"
  "xrsimulator-arm64|xrsimulator|arm64-apple-xros1.0-simulator|VISIONOSSIMULATOR|sdk=xrsimulator*"
)

default_apple_build_slice_names=(
  "macosx-arm64"
  "iphoneos-arm64"
  "iphonesimulator-arm64"
  "xros-arm64"
  "xrsimulator-arm64"
)

selected_apple_build_slices() {
  local requested_slices="${NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES:-}"
  if [[ -z "$requested_slices" ]]; then
    local default_slice_name
    for default_slice_name in "${default_apple_build_slice_names[@]}"; do
      local default_slice_definition
      for default_slice_definition in "${apple_build_slices[@]}"; do
        local known_default_slice_name
        IFS='|' read -r known_default_slice_name _ <<< "$default_slice_definition"
        if [[ "$default_slice_name" == "$known_default_slice_name" ]]; then
          printf '%s\n' "$default_slice_definition"
          break
        fi
      done
    done
    return 0
  fi

  local requested_slice_names=()
  read -r -a requested_slice_names <<< "$requested_slices"
  local requested_slice_name
  for requested_slice_name in "${requested_slice_names[@]}"; do
    local slice_definition
    local matched=0
    for slice_definition in "${apple_build_slices[@]}"; do
      local known_slice_name
      IFS='|' read -r known_slice_name _ <<< "$slice_definition"
      if [[ "$requested_slice_name" == "$known_slice_name" ]]; then
        printf '%s\n' "$slice_definition"
        matched=1
        break
      fi
    done
    if [[ "$matched" == "0" ]]; then
      local valid_slice_names=()
      for slice_definition in "${apple_build_slices[@]}"; do
        local known_slice_name
        IFS='|' read -r known_slice_name _ <<< "$slice_definition"
        valid_slice_names+=("$known_slice_name")
      done
      echo "error: NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES entries must be one of ${valid_slice_names[*]}: ${requested_slice_name}" >&2
      exit 64
    fi
  done
}

runtime_platform_for_apple_sdk() {
  case "$1" in
    macosx)
      printf '%s' "macos"
      ;;
    iphoneos)
      printf '%s' "ios"
      ;;
    iphonesimulator)
      printf '%s' "iossimulator"
      ;;
    appletvos)
      printf '%s' "tvos"
      ;;
    appletvsimulator)
      printf '%s' "tvossimulator"
      ;;
    maccatalyst)
      printf '%s' "maccatalyst"
      ;;
    xros)
      printf '%s' "visionos"
      ;;
    xrsimulator)
      printf '%s' "visionossimulator"
      ;;
    *)
      printf '%s' "$1"
      ;;
  esac
}

first_apple_slice_name() {
  local slice_definition
  slice_definition="$(selected_apple_build_slices | head -n 1)"
  local slice_name
  IFS='|' read -r slice_name _ <<< "$slice_definition"
  printf '%s' "$slice_name"
}

dependency_prefix_for_slice() {
  local slice_name="$1"
  local dependency_root="${2:-${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}}"
  if [[ -z "$dependency_root" ]]; then
    return 0
  fi
  printf '%s/%s' "$dependency_root" "$slice_name"
}

runtime_library_link_name() {
  local library="${1%.a}"
  if [[ "$library" == lib* ]]; then
    library="${library#lib}"
  fi
  printf '%s' "$library"
}

runtime_library_static_artifact() {
  local library="${1%.a}"
  if [[ "$library" != lib* ]]; then
    library="lib${library}"
  fi
  printf 'lib/%s.a' "$library"
}

runtime_library_header_artifact() {
  local library="${1%.a}"
  if [[ "$library" != lib* && "$library" != "dav1d" ]]; then
    library="lib${library}"
  fi
  case "$library" in
    libbluray)
      printf 'include/libbluray/bluray.h'
      ;;
    libsmb2)
      printf 'include/smb2/libsmb2.h'
      ;;
    dav1d|libdav1d)
      printf 'include/dav1d/dav1d.h'
      ;;
    libaom)
      printf 'include/aom/aom_codec.h'
      ;;
    libdvdnav)
      printf 'include/dvdnav/dvdnav.h'
      ;;
    libdvdread)
      printf 'include/dvdread/dvd_reader.h'
      ;;
    libvvdec)
      printf 'include/vvdec/vvdec.h'
      ;;
    libxevd)
      printf 'include/xevd.h'
      ;;
    libdavs2)
      printf 'include/davs2.h'
      ;;
    libuavs3d)
      printf 'include/uavs3d.h'
      ;;
    libsvtjpegxs)
      printf 'include/SvtJpegxsDec.h'
      ;;
    libjxl)
      printf 'include/jxl/decode.h'
      ;;
    libvpx)
      printf 'include/vpx/vpx_decoder.h'
      ;;
    libopenjpeg)
      printf 'include/openjpeg-2.5/openjpeg.h'
      ;;
    libopenmpt)
      printf 'include/libopenmpt/libopenmpt.h'
      ;;
    libmodplug)
      printf 'include/libmodplug/modplug.h'
      ;;
    libmpeghdec)
      printf 'include/mpeghdecoder.h'
      ;;
    liblc3)
      printf 'include/lc3.h'
      ;;
    libcodec2)
      printf 'include/codec2/codec2.h'
      ;;
    libcelt)
      printf 'include/celt/celt.h'
      ;;
    libspeex)
      printf 'include/speex/speex.h'
      ;;
    libilbc)
      printf 'include/ilbc.h'
      ;;
    libgsm)
      printf 'include/gsm.h'
      ;;
    libopencore-amrnb)
      printf 'include/opencore-amrnb/interf_dec.h'
      ;;
    libopencore-amrwb)
      printf 'include/opencore-amrwb/dec_if.h'
      ;;
    libzvbi)
      printf 'include/libzvbi.h'
      ;;
    libaribcaption)
      printf 'include/aribcaption/aribcaption.h'
      ;;
    libaribb24)
      printf 'include/aribb24/aribb24.h'
      ;;
    libsmbclient)
      printf 'include/libsmbclient.h'
      ;;
    libssh)
      printf 'include/libssh/sftp.h'
      ;;
    libnfs)
      printf 'include/nfsc/libnfs.h'
      ;;
    libsrt)
      printf 'include/srt/srt.h'
      ;;
    librist)
      printf 'include/librist/librist.h'
      ;;
    librtmp)
      printf 'include/librtmp/rtmp.h'
      ;;
    librabbitmq)
      printf 'include/amqp.h'
      ;;
    libzmq)
      printf 'include/zmq.h'
      ;;
  esac
}

is_default_network_runtime_library() {
  case "$1" in
    libsmbclient|libssh|libnfs|libsrt|librist|librtmp|librabbitmq|libzmq)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

modern_video_runtime_libraries=(
  "libvvdec"
  "libxevd"
  "libdavs2"
  "libuavs3d"
  "libopenjpeg"
  "libsvtjpegxs"
  "libjxl"
  "libvpx"
)

modern_video_configure_flags=(
  "--enable-libvvdec"
  "--enable-libxevd"
  "--enable-libdavs2"
  "--enable-libuavs3d"
  "--enable-libopenjpeg"
  "--enable-libsvtjpegxs"
  "--enable-libjxl"
  "--enable-libvpx"
)

ffmpeg_link_profile() {
  local profile="${NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE:-base}"
  case "$profile" in
    full|base)
      printf '%s' "$profile"
      ;;
    *)
      echo "error: NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE must be full or base: ${profile}" >&2
      exit 64
      ;;
  esac
}

swiftpm_link_mode() {
  local mode="${NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE:-search}"
  case "$mode" in
    search|static|framework)
      printf '%s' "$mode"
      ;;
    *)
      echo "error: NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE must be search, static, or framework: ${mode}" >&2
      exit 64
      ;;
  esac
}

runtime_framework_name="NsuratorPlayerCoreFFmpegRuntime"

runtime_framework_packager() {
  printf '%s/package-apple-ffmpeg-runtime-framework.sh' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}

runtime_framework_relative_root() {
  local relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_FRAMEWORK_RELATIVE_PATH:-frameworks}"
  case "$relative_root" in
    ""|"."|/*|".."|../*|*/../*|*/..)
      echo "error: artifact framework relative path must stay inside the artifact root" >&2
      exit 64
      ;;
  esac
  relative_root="${relative_root#./}"
  printf '%s' "${relative_root%/}"
}

runtime_framework_install_name() {
  printf '@rpath/%s.framework/Versions/A/%s' "$runtime_framework_name" "$runtime_framework_name"
}

runtime_framework_binary_sha256() {
  /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

runtime_framework_binary_uuid() {
  /usr/bin/otool -l "$1" | /usr/bin/awk '/cmd LC_UUID/{inside=1} inside && $1 == "uuid" {print $2; exit}'
}

static_pkg_config_packages() {
  printf '%s' "${NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_STATIC_PKG_CONFIG_PACKAGES:-libavfilter libavformat libavcodec libavutil libswresample libswscale libbluray}"
}

append_unique_search_dir() {
  local search_dir="$1"
  shift
  local existing_dir
  for existing_dir in "$@"; do
    if [[ "$existing_dir" == "$search_dir" ]]; then
      return 1
    fi
  done
  printf '%s' "$search_dir"
}

resolve_direct_link_artifact() {
  local link_name="$1"
  shift
  local search_dir
  for search_dir in "$@"; do
    if [[ -f "${search_dir}/lib${link_name}.a" ]]; then
      printf '%s' "${search_dir}/lib${link_name}.a"
      return 0
    fi
  done
  for search_dir in "$@"; do
    if [[ -f "${search_dir}/lib${link_name}.dylib" ]]; then
      printf '%s' "${search_dir}/lib${link_name}.dylib"
      return 0
    fi
  done
}

append_unique_swiftpm_linker_flags() {
  local flags="$1"
  local emitted="$2"
  local linker_flags="$3"
  if [[ "$emitted" == *" ${linker_flags} "* ]]; then
    printf '%s\n%s' "$flags" "$emitted"
    return 0
  fi
  flags="${flags} ${linker_flags}"
  emitted="${emitted}${linker_flags} "
  printf '%s\n%s' "$flags" "$emitted"
}

join_colon_paths() {
  local IFS=':'
  printf '%s' "$*"
}

static_pkg_config_swiftpm_flags() {
  local prefix="$1"
  local dependency_library_prefix="$2"
  local already_emitted_flags="${3:-}"
  if ! command -v pkg-config >/dev/null 2>&1; then
    return 0
  fi

  local package_names=()
  read -r -a package_names <<< "$(static_pkg_config_packages)"
  if [[ ${#package_names[@]} -eq 0 ]]; then
    return 0
  fi

  local pkg_config_libdirs=("${prefix}/lib/pkgconfig")
  if [[ "$dependency_library_prefix" != "$prefix" ]]; then
    pkg_config_libdirs+=("${dependency_library_prefix}/lib/pkgconfig")
  fi
  local pkg_config_libdir
  pkg_config_libdir="$(join_colon_paths "${pkg_config_libdirs[@]}")"

  local package_flags
  if ! package_flags="$(env PKG_CONFIG_LIBDIR="$pkg_config_libdir" PKG_CONFIG_PATH= pkg-config --libs --static "${package_names[@]}" 2>/dev/null)"; then
    return 0
  fi

  local tokens=()
  read -r -a tokens <<< "$package_flags"
  local search_dirs=("${prefix}/lib")
  if [[ "$dependency_library_prefix" != "$prefix" ]]; then
    search_dirs+=("${dependency_library_prefix}/lib")
  fi
  if [[ -n "${NSURATOR_PLAYER_CORE_FFMPEG_STATIC_LINK_SEARCH_DIRS:-}" ]]; then
    local extra_search_dir
    local extra_search_dirs
    IFS=':' read -r -a extra_search_dirs <<< "$NSURATOR_PLAYER_CORE_FFMPEG_STATIC_LINK_SEARCH_DIRS"
    for extra_search_dir in "${extra_search_dirs[@]}"; do
      if [[ -n "$extra_search_dir" ]]; then
        local unique_dir
        unique_dir="$(append_unique_search_dir "$extra_search_dir" "${search_dirs[@]}")" || true
        if [[ -n "$unique_dir" ]]; then
          search_dirs+=("$unique_dir")
        fi
      fi
    done
  fi

  local flags=""
  local emitted=" ${already_emitted_flags} "
  local token
  local expect_framework_name=0
  for token in "${tokens[@]}"; do
    if [[ "$expect_framework_name" == "1" ]]; then
      local updated
      updated="$(append_unique_swiftpm_linker_flags "$flags" "$emitted" "-Xlinker -framework -Xlinker ${token}")"
      flags="${updated%%$'\n'*}"
      emitted="${updated#*$'\n'}"
      expect_framework_name=0
      continue
    fi

    case "$token" in
      -L*)
        local search_dir="${token#-L}"
        local unique_dir
        unique_dir="$(append_unique_search_dir "$search_dir" "${search_dirs[@]}")" || true
        if [[ -n "$unique_dir" ]]; then
          search_dirs+=("$unique_dir")
        fi
        ;;
      -l*)
        local link_name="${token#-l}"
        local link_artifact
        link_artifact="$(resolve_direct_link_artifact "$link_name" "${search_dirs[@]}")"
        local linker_flags
        if [[ -n "$link_artifact" ]]; then
          linker_flags="-Xlinker $(quote "$link_artifact")"
        else
          linker_flags="-Xlinker -l${link_name}"
        fi
        local updated
        updated="$(append_unique_swiftpm_linker_flags "$flags" "$emitted" "$linker_flags")"
        flags="${updated%%$'\n'*}"
        emitted="${updated#*$'\n'}"
        ;;
      -framework)
        expect_framework_name=1
        ;;
      -pthread)
        ;;
      /*.a|/*.dylib)
        local updated
        updated="$(append_unique_swiftpm_linker_flags "$flags" "$emitted" "-Xlinker $(quote "$token")")"
        flags="${updated%%$'\n'*}"
        emitted="${updated#*$'\n'}"
        ;;
      *)
        ;;
    esac
  done

  local updated
  updated="$(append_unique_swiftpm_linker_flags "$flags" "$emitted" "-Xlinker -lc++")"
  flags="${updated%%$'\n'*}"
  emitted="${updated#*$'\n'}"

  printf '%s' "$flags"
}

network_protocol_configure_flags=(
  "--enable-libsmbclient"
  "--enable-libssh"
  "--enable-libsrt"
  "--enable-librist"
  "--enable-librtmp"
  "--enable-librabbitmq"
  "--enable-libzmq"
  "--enable-protocol=async"
  "--enable-protocol=cache"
  "--enable-protocol=concat"
  "--enable-protocol=concatf"
  "--enable-protocol=crypto"
  "--enable-protocol=data"
  "--enable-protocol=dtls"
  "--enable-protocol=fd"
  "--enable-protocol=ftp"
  "--enable-protocol=ftps"
  "--enable-protocol=gopher"
  "--enable-protocol=gophers"
  "--enable-protocol=http"
  "--enable-protocol=https"
  "--enable-protocol=httpproxy"
  "--enable-protocol=ipfs"
  "--enable-protocol=ipns"
  "--enable-protocol=mmsh"
  "--enable-protocol=mmst"
  "--enable-protocol=pipe"
  "--enable-demuxer=rtp"
  "--enable-demuxer=rtsp"
  "--enable-demuxer=sap"
  "--enable-protocol=sctp"
  "--enable-protocol=shared"
  "--enable-protocol=srtp"
  "--enable-protocol=subfile"
  "--enable-protocol=tcp"
  "--enable-protocol=tls"
  "--enable-protocol=udp"
  "--enable-protocol=udplite"
  "--enable-protocol=unix"
  "--enable-securetransport"
)

extra_runtime_libraries() {
  local libraries=()
  local extra_ffmpeg_configure_flags="${NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS:-}"
  if [[ -n "$extra_ffmpeg_configure_flags" ]]; then
    local configure_flags=()
    local flag
    read -r -a configure_flags <<< "$extra_ffmpeg_configure_flags"
    for flag in "${configure_flags[@]}"; do
      if [[ "$flag" == --enable-lib* ]]; then
        libraries+=("${flag#--enable-}")
      fi
    done
  fi
  local extra_runtime_libraries="${NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES:-}"
  if [[ -n "$extra_runtime_libraries" ]]; then
    local explicit_libraries=()
    read -r -a explicit_libraries <<< "$extra_runtime_libraries"
    libraries+=("${explicit_libraries[@]}")
  fi
  if [[ ${#libraries[@]} -eq 0 ]]; then
    return 0
  fi
  local emitted=" "
  local library
  for library in "${libraries[@]}"; do
    if network_protocols_enabled && is_default_network_runtime_library "$library"; then
      continue
    fi
    if [[ -n "$library" && "$emitted" != *" ${library} "* ]]; then
      emitted="${emitted}${library} "
      printf '%s\n' "$library"
    fi
  done
}

extra_runtime_library_enabled() {
  local expected_library="$1"
  local runtime_library
  while IFS= read -r runtime_library; do
    if [[ "$(runtime_library_link_name "$runtime_library")" == "$(runtime_library_link_name "$expected_library")" ]]; then
      return 0
    fi
  done < <(extra_runtime_libraries)
  return 1
}

libnfs_custom_avio_enabled() {
  network_protocols_enabled || extra_runtime_library_enabled libnfs
}

libdvdnav_shim_enabled() {
  if [[ "$(ffmpeg_link_profile)" == "full" ]]; then
    return 0
  fi
  extra_runtime_library_enabled libdvdnav &&
    extra_runtime_library_enabled libdvdread
}

runtime_preflight_configure_flags() {
  local flag
  for flag in "$@"; do
    case "$flag" in
      --disable-autodetect|"")
        ;;
      *)
        printf '%s\n' "$flag"
        ;;
    esac
  done
}

print_swiftpm_flags() {
  local prefix="${1:-}"
  if [[ -z "$prefix" ]]; then
    echo "error: --print-swiftpm-flags requires an install prefix" >&2
    exit 64
  fi

  local profile
  profile="$(ffmpeg_link_profile)"
  local link_mode
  link_mode="$(swiftpm_link_mode)"
  local dep_prefix="${2:-${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}}"
  local dependency_library_prefix="$prefix"
  if [[ -n "$dep_prefix" ]]; then
    dependency_library_prefix="$dep_prefix"
  fi

  local flags="-Xcc -DNPC_FFMPEG_CSHIM_ENABLE_LIBAV=1 -Xcc -DNPC_FFMPEG_CSHIM_ENABLE_LIBBLURAY=1 -Xcc $(quote "-I${prefix}/include")"
  if extra_runtime_library_enabled libsmb2; then
    flags="${flags} -Xcc -DNPC_FFMPEG_CSHIM_ENABLE_LIBSMB2=1"
  fi
  if libnfs_custom_avio_enabled; then
    flags="${flags} -Xcc -DNPC_FFMPEG_CSHIM_ENABLE_LIBNFS=1"
  fi
  if libdvdnav_shim_enabled; then
    flags="${flags} -Xcc -DNPC_FFMPEG_CSHIM_ENABLE_LIBDVDNAV=1"
  fi
  if [[ "$link_mode" == "framework" ]]; then
    # The framework carries every FFmpeg, libbluray, and dav1d object and links
    # its own system dependencies, so the consumer links only the framework and
    # keeps the headers. The -rpath lets swift build/test/run load the
    # artifact's copy; an app bundle replaces it with a bundle-relative rpath.
    local framework_dir="${NSURATOR_PLAYER_CORE_FFMPEG_FRAMEWORK_DIR:-}"
    if [[ -z "$framework_dir" ]]; then
      echo "error: framework link mode requires NSURATOR_PLAYER_CORE_FFMPEG_FRAMEWORK_DIR" >&2
      exit 64
    fi
    if [[ -n "$dep_prefix" ]]; then
      flags="${flags} -Xcc $(quote "-I${dep_prefix}/include")"
    fi
    flags="${flags} -Xlinker $(quote "-F${framework_dir}") -Xlinker -framework -Xlinker ${runtime_framework_name} -Xlinker -rpath -Xlinker $(quote "$framework_dir")"
    local extra_framework_swiftpm_flags="${NSURATOR_PLAYER_CORE_EXTRA_SWIFTPM_FLAGS:-}"
    if [[ -n "$extra_framework_swiftpm_flags" ]]; then
      flags="${flags} ${extra_framework_swiftpm_flags}"
    fi
    printf '%s\n' "$flags"
    return 0
  fi
  if [[ "$link_mode" == "static" ]]; then
    flags="${flags} -Xlinker $(quote "${prefix}/$(runtime_library_static_artifact libavfilter)")"
    flags="${flags} -Xlinker $(quote "${prefix}/$(runtime_library_static_artifact libavformat)")"
    flags="${flags} -Xlinker $(quote "${prefix}/$(runtime_library_static_artifact libavcodec)")"
    flags="${flags} -Xlinker $(quote "${prefix}/$(runtime_library_static_artifact libavutil)")"
    flags="${flags} -Xlinker $(quote "${prefix}/$(runtime_library_static_artifact libswresample)")"
    flags="${flags} -Xlinker $(quote "${prefix}/$(runtime_library_static_artifact libswscale)")"
    flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact libbluray)")"
  else
    flags="${flags} -Xlinker $(quote "-L${prefix}/lib") -Xlinker -lavfilter -Xlinker -lavformat -Xlinker -lavcodec -Xlinker -lavutil -Xlinker -lswresample -Xlinker -lswscale -Xlinker -lbluray"
  fi
  if [[ "$profile" == "full" ]]; then
    if [[ "$link_mode" == "static" ]]; then
      flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact libdvdnav)")"
      flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact libdvdread)")"
      flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact dav1d)")"
    else
      flags="${flags} -Xlinker -ldvdnav -Xlinker -ldvdread -Xlinker -ldav1d"
    fi
  fi
  flags="${flags} $(apple_framework_swiftpm_flags) -Xlinker -lz -Xlinker -lbz2 -Xlinker -liconv"
  local runtime_library
  if [[ "$profile" == "full" ]]; then
    for runtime_library in "${modern_video_runtime_libraries[@]}"; do
      if [[ "$link_mode" == "static" ]]; then
        flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact "$runtime_library")")"
      else
        flags="${flags} -Xlinker -l$(runtime_library_link_name "$runtime_library")"
      fi
    done
  fi
  if [[ -n "$dep_prefix" ]]; then
    flags="${flags} -Xcc $(quote "-I${dep_prefix}/include") -Xlinker $(quote "-L${dep_prefix}/lib")"
  fi
  if network_protocols_enabled; then
    if [[ "$link_mode" == "static" ]]; then
      flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact libsmbclient)")"
      flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact libssh)")"
      flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact libnfs)")"
      flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact libsrt)")"
      flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact librist)")"
      flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact librtmp)")"
      flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact librabbitmq)")"
      flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact libzmq)")"
      flags="${flags} -Xlinker -framework -Xlinker Security"
    else
      flags="${flags} -Xlinker -lsmbclient -Xlinker -lssh -Xlinker -lnfs -Xlinker -lsrt -Xlinker -lrist -Xlinker -lrtmp -Xlinker -lrabbitmq -Xlinker -lzmq -Xlinker -framework -Xlinker Security"
    fi
  fi
  while IFS= read -r runtime_library; do
    if [[ "$link_mode" == "static" ]]; then
      flags="${flags} -Xlinker $(quote "${dependency_library_prefix}/$(runtime_library_static_artifact "$runtime_library")")"
    else
      flags="${flags} -Xlinker -l$(runtime_library_link_name "$runtime_library")"
    fi
  done < <(extra_runtime_libraries)
  if [[ "$link_mode" == "static" ]]; then
    local pkg_config_flags
    pkg_config_flags="$(static_pkg_config_swiftpm_flags "$prefix" "$dependency_library_prefix" "$flags")"
    if [[ -n "$pkg_config_flags" ]]; then
      flags="${flags} ${pkg_config_flags}"
    fi
  fi
  local extra_swiftpm_flags="${NSURATOR_PLAYER_CORE_EXTRA_SWIFTPM_FLAGS:-}"
  if [[ -n "$extra_swiftpm_flags" ]]; then
    flags="${flags} ${extra_swiftpm_flags}"
  fi
  printf '%s\n' "$flags"
}

print_artifact_scoped_swiftpm_flags() {
  local prefix="$1"
  local dep_prefix="${2:-}"
  local pkg_config_dirs=("${prefix}/lib/pkgconfig")
  if [[ -n "$dep_prefix" ]]; then
    pkg_config_dirs+=("${dep_prefix}/lib/pkgconfig")
  fi
  local pkg_config_libdir
  pkg_config_libdir="$(join_colon_paths "${pkg_config_dirs[@]}")"

  (
    export PKG_CONFIG_LIBDIR="$pkg_config_libdir"
    unset PKG_CONFIG_PATH
    print_swiftpm_flags "$prefix" "$dep_prefix"
  )
}

artifact_root_without_trailing_slash() {
  local artifact_root="$1"
  while [[ "$artifact_root" != "/" && "$artifact_root" == */ ]]; do
    artifact_root="${artifact_root%/}"
  done
  printf '%s' "$artifact_root"
}

artifact_root_absolute_without_trailing_slash() {
  local artifact_root
  artifact_root="$(artifact_root_without_trailing_slash "$1")"
  case "$artifact_root" in
    /*)
      printf '%s' "$artifact_root"
      ;;
    .)
      printf '%s' "$PWD"
      ;;
    ./*)
      printf '%s/%s' "$PWD" "${artifact_root#./}"
      ;;
    *)
      printf '%s/%s' "$PWD" "$artifact_root"
      ;;
  esac
}

artifact_dependency_root() {
  local artifact_root="$1"
  local dependency_root="${artifact_root}/dependencies"
  if [[ -d "$dependency_root" ]]; then
    printf '%s' "$dependency_root"
  fi
}

artifact_manifest_slice_prefixes() {
  local artifact_root="$1"
  local slice_name="$2"
  python3 - \
    "$artifact_root" \
    "$slice_name" \
    "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json" \
    "${artifact_root}/nsurator-player-core-ffmpeg-visionos-manifest.json" <<'PY'
import json
import os
import sys

artifact_root = sys.argv[1]
slice_name = sys.argv[2]
manifest_paths = sys.argv[3:]

def string_value(mapping, key):
    value = mapping.get(key)
    return value if isinstance(value, str) and value else ""

def resolve_relative(path):
    if not path:
        return ""
    if os.path.isabs(path):
        return path
    path = path[2:] if path.startswith("./") else path
    if path == ".":
        return artifact_root
    return os.path.join(artifact_root, path)

def slice_path(relative_root, name):
    if not relative_root:
        return ""
    relative_root = relative_root.rstrip("/")
    if relative_root == ".":
        return name
    return os.path.join(relative_root, name)

for manifest_path in manifest_paths:
    if not os.path.isfile(manifest_path):
        continue
    with open(manifest_path, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    slices = manifest.get("slices")
    if not isinstance(slices, list):
        continue
    for slice_manifest in slices:
        if not isinstance(slice_manifest, dict):
            continue
        if string_value(slice_manifest, "name") != slice_name:
            continue

        ffmpeg_relative = string_value(slice_manifest, "ffmpegPrefixRelativePath")
        if not ffmpeg_relative:
            ffmpeg_relative = slice_path(
                string_value(manifest, "installRootRelativePath"),
                slice_name,
            )
        ffmpeg_prefix = resolve_relative(ffmpeg_relative)
        if not ffmpeg_prefix:
            ffmpeg_prefix = string_value(slice_manifest, "ffmpegPrefix")
        if not ffmpeg_prefix:
            ffmpeg_prefix = os.path.join(artifact_root, "install", slice_name)

        dependency_relative = string_value(slice_manifest, "dependencyPrefixRelativePath")
        if not dependency_relative:
            dependency_relative = slice_path(
                string_value(manifest, "dependencyRootRelativePath"),
                slice_name,
            )
        dependency_prefix = resolve_relative(dependency_relative)
        if not dependency_prefix:
            dependency_prefix = string_value(slice_manifest, "dependencyPrefix")
        if not dependency_prefix:
            default_dependency_prefix = os.path.join(
                artifact_root,
                "dependencies",
                slice_name,
            )
            if os.path.isdir(default_dependency_prefix):
                dependency_prefix = default_dependency_prefix

        print(ffmpeg_prefix)
        print(dependency_prefix)
        sys.exit(0)

sys.exit(1)
PY
}

artifact_slice_prefixes_for_consumer() {
  local artifact_root="$1"
  local slice_name="$2"
  local default_ffmpeg_prefix="${artifact_root}/install/${slice_name}"
  local default_dependency_prefix=""
  local dependency_root
  dependency_root="$(artifact_dependency_root "$artifact_root")"
  if [[ -n "$dependency_root" ]]; then
    default_dependency_prefix="${dependency_root}/${slice_name}"
  fi

  local resolved_prefixes
  if resolved_prefixes="$(artifact_manifest_slice_prefixes "$artifact_root" "$slice_name")"; then
    local ffmpeg_prefix="${resolved_prefixes%%$'\n'*}"
    local dependency_prefix=""
    if [[ "$resolved_prefixes" == *$'\n'* ]]; then
      dependency_prefix="${resolved_prefixes#*$'\n'}"
    fi
    if [[ -n "$ffmpeg_prefix" ]]; then
      printf '%s\n%s' "$ffmpeg_prefix" "$dependency_prefix"
      return 0
    fi
  fi

  printf '%s\n%s' "$default_ffmpeg_prefix" "$default_dependency_prefix"
}

read_artifact_link_profile() {
  local artifact_root="$1"
  python3 - \
    "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json" \
    "${artifact_root}/nsurator-player-core-ffmpeg-visionos-manifest.json" <<'PY'
import json
import os
import sys

for manifest_path in sys.argv[1:]:
    if not os.path.isfile(manifest_path):
        continue
    with open(manifest_path, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    profile = manifest.get("linkProfile") or ""
    if profile:
        print(profile)
        break
PY
}

read_artifact_swiftpm_link_mode() {
  local artifact_root="$1"
  python3 - \
    "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json" \
    "${artifact_root}/nsurator-player-core-ffmpeg-visionos-manifest.json" <<'PY'
import json
import os
import sys

for manifest_path in sys.argv[1:]:
    if not os.path.isfile(manifest_path):
        continue
    with open(manifest_path, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    mode = manifest.get("swiftpmLinkMode") or ""
    if mode:
        print(mode)
        break
PY
}

read_artifact_slice_runtime_framework_relative_path() {
  local artifact_root="$1"
  local slice_name="$2"
  python3 - \
    "$slice_name" \
    "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json" \
    "${artifact_root}/nsurator-player-core-ffmpeg-visionos-manifest.json" <<'PY'
import json
import os
import sys

slice_name = sys.argv[1]
for manifest_path in sys.argv[2:]:
    if not os.path.isfile(manifest_path):
        continue
    with open(manifest_path, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    for slice_manifest in manifest.get("slices") or []:
        if isinstance(slice_manifest, dict) and slice_manifest.get("name") == slice_name:
            value = slice_manifest.get("runtimeFrameworkRelativePath")
            if isinstance(value, str) and value:
                print(value)
            sys.exit(0)
    break
PY
}

read_artifact_network_protocols_enabled() {
  local artifact_root="$1"
  python3 - \
    "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json" \
    "${artifact_root}/nsurator-player-core-ffmpeg-visionos-manifest.json" <<'PY'
import json
import os
import sys

for manifest_path in sys.argv[1:]:
    if not os.path.isfile(manifest_path):
        continue
    with open(manifest_path, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    if manifest.get("networkProtocolsEnabled") is True:
        print("1")
    elif manifest.get("networkProtocolsEnabled") is False:
        print("0")
    break
PY
}

read_artifact_required_runtime_libraries() {
  local artifact_root="$1"
  python3 - \
    "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json" \
    "${artifact_root}/nsurator-player-core-ffmpeg-visionos-manifest.json" <<'PY'
import json
import os
import sys

for manifest_path in sys.argv[1:]:
    if not os.path.isfile(manifest_path):
        continue
    with open(manifest_path, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    for library in manifest.get("requiredRuntimeLibraries") or []:
        if isinstance(library, str) and library:
            print(library)
    break
PY
}

read_artifact_required_configure_flags() {
  local artifact_root="$1"
  python3 - \
    "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json" \
    "${artifact_root}/nsurator-player-core-ffmpeg-visionos-manifest.json" <<'PY'
import json
import os
import sys

for manifest_path in sys.argv[1:]:
    if not os.path.isfile(manifest_path):
        continue
    with open(manifest_path, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    for flag in manifest.get("requiredConfigureFlags") or []:
        if isinstance(flag, str) and flag:
            print(flag)
    break
PY
}

adopt_artifact_link_profile() {
  local artifact_root="$1"
  if [[ -n "${NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE:-}" ]]; then
    return 0
  fi

  local artifact_profile
  artifact_profile="$(read_artifact_link_profile "$artifact_root")"
  if [[ -z "$artifact_profile" ]]; then
    return 0
  fi
  NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE="$artifact_profile"
  export NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE
  ffmpeg_link_profile >/dev/null
}

adopt_artifact_swiftpm_link_mode() {
  local artifact_root="$1"
  if [[ -n "${NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE:-}" ]]; then
    return 0
  fi

  local artifact_link_mode
  artifact_link_mode="$(read_artifact_swiftpm_link_mode "$artifact_root")"
  if [[ -z "$artifact_link_mode" ]]; then
    return 0
  fi
  NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE="$artifact_link_mode"
  export NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE
  swiftpm_link_mode >/dev/null
}

adopt_artifact_network_protocols() {
  local artifact_root="$1"
  local artifact_network_enabled
  artifact_network_enabled="$(read_artifact_network_protocols_enabled "$artifact_root")"
  case "$artifact_network_enabled" in
    1)
      NSURATOR_PLAYER_CORE_ENABLE_NETWORK_PROTOCOLS=1
      export NSURATOR_PLAYER_CORE_ENABLE_NETWORK_PROTOCOLS
      ;;
    0)
      unset NSURATOR_PLAYER_CORE_ENABLE_NETWORK_PROTOCOLS
      ;;
  esac
}

runtime_library_is_default_for_current_configuration() {
  local library="${1%.a}"
  case "$library" in
    libbluray|bluray)
      return 0
      ;;
  esac

  if [[ "$(ffmpeg_link_profile)" == "full" ]]; then
    case "$library" in
      dav1d|libdav1d|libdvdnav|dvdnav|libdvdread|dvdread|libvvdec|libxevd|libdavs2|libuavs3d|libopenjpeg|libsvtjpegxs|libjxl|libvpx)
        return 0
        ;;
    esac
  fi

  if network_protocols_enabled && is_default_network_runtime_library "$library"; then
    return 0
  fi
  return 1
}

configure_flag_is_default_for_current_configuration() {
  local flag="$1"
  case "$flag" in
    --enable-libbluray)
      return 0
      ;;
  esac

  local default_flag
  if [[ "$(ffmpeg_link_profile)" == "full" ]]; then
    for default_flag in \
      "--enable-libdav1d" \
      "--enable-libdvdnav" \
      "--enable-libdvdread" \
      "${modern_video_configure_flags[@]}"; do
      if [[ "$flag" == "$default_flag" ]]; then
        return 0
      fi
    done
  fi

  if network_protocols_enabled; then
    for default_flag in "${network_protocol_configure_flags[@]}"; do
      if [[ "$flag" == "$default_flag" ]]; then
        return 0
      fi
    done
  fi
  return 1
}

adopt_artifact_required_configure_flags() {
  local artifact_root="$1"
  local existing_flags=" ${NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS:-} "
  local missing_flags=()
  local flag
  while IFS= read -r flag; do
    if [[ -z "$flag" ]]; then
      continue
    fi
    if configure_flag_is_default_for_current_configuration "$flag"; then
      continue
    fi
    if [[ "$existing_flags" != *" ${flag} "* ]]; then
      existing_flags="${existing_flags}${flag} "
      missing_flags+=("$flag")
    fi
  done < <(read_artifact_required_configure_flags "$artifact_root")

  if [[ ${#missing_flags[@]} -eq 0 ]]; then
    return 0
  fi
  if [[ -n "${NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS:-}" ]]; then
    NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS="${NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS} ${missing_flags[*]}"
  else
    NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS="${missing_flags[*]}"
  fi
  export NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS
}

adopt_artifact_required_runtime_libraries() {
  local artifact_root="$1"
  local existing_libraries=" ${NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES:-} "
  local missing_libraries=()
  local library
  while IFS= read -r library; do
    if [[ -z "$library" ]]; then
      continue
    fi
    if runtime_library_is_default_for_current_configuration "$library"; then
      continue
    fi
    if [[ "$existing_libraries" != *" ${library} "* ]]; then
      existing_libraries="${existing_libraries}${library} "
      missing_libraries+=("$library")
    fi
  done < <(read_artifact_required_runtime_libraries "$artifact_root")

  if [[ ${#missing_libraries[@]} -eq 0 ]]; then
    return 0
  fi
  if [[ -n "${NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES:-}" ]]; then
    NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES="${NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES} ${missing_libraries[*]}"
  else
    NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES="${missing_libraries[*]}"
  fi
  export NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES
}

adopt_artifact_manifest_configuration() {
  local artifact_root="$1"
  adopt_artifact_link_profile "$artifact_root"
  adopt_artifact_swiftpm_link_mode "$artifact_root"
  adopt_artifact_network_protocols "$artifact_root"
  adopt_artifact_required_configure_flags "$artifact_root"
  adopt_artifact_required_runtime_libraries "$artifact_root"
}

require_artifact_slice_name() {
  local slice_name="$1"
  local slice_definition
  local valid_slice_names=()
  for slice_definition in "${apple_build_slices[@]}"; do
    local known_slice_name
    IFS='|' read -r known_slice_name _ <<< "$slice_definition"
    valid_slice_names+=("$known_slice_name")
    if [[ "$slice_name" == "$known_slice_name" ]]; then
      return 0
    fi
  done
  echo "error: artifact slice must be one of ${valid_slice_names[*]}: ${slice_name:-missing}" >&2
  exit 64
}

print_artifact_swiftpm_flags() {
  local artifact_root="${1:-}"
  local slice_name="${2:-}"
  if [[ -z "$artifact_root" || -z "$slice_name" ]]; then
    echo "error: --print-artifact-swiftpm-flags requires an artifact root and slice name" >&2
    exit 64
  fi

  require_artifact_slice_name "$slice_name"
  artifact_root="$(artifact_root_absolute_without_trailing_slash "$artifact_root")"
  adopt_artifact_manifest_configuration "$artifact_root"

  local resolved_prefixes
  resolved_prefixes="$(artifact_slice_prefixes_for_consumer "$artifact_root" "$slice_name")"
  local ffmpeg_prefix="${resolved_prefixes%%$'\n'*}"
  local dep_prefix=""
  if [[ "$resolved_prefixes" == *$'\n'* ]]; then
    dep_prefix="${resolved_prefixes#*$'\n'}"
  fi

  print_artifact_scoped_swiftpm_flags "$ffmpeg_prefix" "$dep_prefix"
}

shell_single_quote() {
  local value="$1"
  value="${value//\'/\'\\\'\'}"
  printf "'%s'" "$value"
}

print_shell_export() {
  local name="$1"
  local value="$2"
  printf 'export %s=%s\n' "$name" "$(shell_single_quote "$value")"
}

apple_build_script_family() {
  case "$build_script_name" in
    *apple*)
      printf '%s' "apple"
      ;;
    *)
      printf '%s' "visionos"
      ;;
  esac
}

selected_apple_slice_names() {
  local slice_names=()
  local slice_definition
  while IFS= read -r slice_definition; do
    if [[ -z "$slice_definition" ]]; then
      continue
    fi
    local slice_name
    IFS='|' read -r slice_name _ <<< "$slice_definition"
    slice_names+=("$slice_name")
  done < <(selected_apple_build_slices)
  printf '%s' "${slice_names[*]}"
}

print_no_space_build_env() {
  local build_root="${1:-}"
  if [[ -z "$build_root" ]]; then
    echo "error: --print-no-space-build-env requires a root path" >&2
    exit 64
  fi
  if path_contains_whitespace "$build_root"; then
    echo "error: --print-no-space-build-env root cannot contain whitespace: ${build_root}" >&2
    exit 64
  fi

  build_root="$(artifact_root_without_trailing_slash "$build_root")"
  local build_family
  build_family="$(apple_build_script_family)"

  print_shell_export "NSURATOR_PLAYER_CORE_NO_SPACE_BUILD_ROOT" "$build_root"
  print_shell_export "FFMPEG_SOURCE_DIR" "${build_root}/sources/ffmpeg"
  print_shell_export "DAV1D_SOURCE_DIR" "${build_root}/sources/dav1d"
  print_shell_export "LIBBLURAY_SOURCE_DIR" "${build_root}/sources/libbluray"
  print_shell_export "LIBDVDREAD_SOURCE_DIR" "${build_root}/sources/libdvdread"
  print_shell_export "LIBDVDNAV_SOURCE_DIR" "${build_root}/sources/libdvdnav"
  print_shell_export "NSURATOR_PLAYER_CORE_FFMPEG_BUILD_DIR" "${build_root}/ffmpeg-${build_family}/build"
  print_shell_export "NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR" "${build_root}/ffmpeg-${build_family}/install"
  print_shell_export "NSURATOR_PLAYER_CORE_DAV1D_BUILD_DIR" "${build_root}/dav1d-${build_family}/build"
  print_shell_export "NSURATOR_PLAYER_CORE_DAV1D_INSTALL_DIR" "${build_root}/dav1d-${build_family}/install"
  print_shell_export "NSURATOR_PLAYER_CORE_LIBBLURAY_BUILD_DIR" "${build_root}/libbluray-${build_family}/build"
  print_shell_export "NSURATOR_PLAYER_CORE_LIBBLURAY_INSTALL_DIR" "${build_root}/libbluray-${build_family}/install"
  print_shell_export "NSURATOR_PLAYER_CORE_LIBDVDREAD_BUILD_DIR" "${build_root}/libdvdread-${build_family}/build"
  print_shell_export "NSURATOR_PLAYER_CORE_LIBDVDNAV_BUILD_DIR" "${build_root}/libdvdnav-${build_family}/build"
  print_shell_export "NSURATOR_PLAYER_CORE_LIBDVD_INSTALL_DIR" "${build_root}/deps/install"
  print_shell_export "NSURATOR_PLAYER_CORE_DEP_PREFIX" "${build_root}/deps/install"
  print_shell_export "NSURATOR_PLAYER_CORE_ARTIFACT_INSTALL_RELATIVE_PATH" "install"
  print_shell_export "NSURATOR_PLAYER_CORE_ARTIFACT_DEP_RELATIVE_PATH" "dependencies"
  print_shell_export "NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES" "$(selected_apple_slice_names)"
  print_shell_export "NSURATOR_PLAYER_CORE_MESON" "${build_root}/tools/meson"
  print_shell_export "PYTHONPATH" "${build_root}/python-tools"
}

prepare_no_space_source_path() {
  local env_name="$1"
  local link_path="$2"
  local source_path="${!env_name:-}"

  if [[ -z "$source_path" ]]; then
    mkdir -p "$link_path"
    return
  fi
  if [[ ! -e "$source_path" ]]; then
    echo "error: ${env_name} does not exist: ${source_path}" >&2
    exit 66
  fi
  if [[ -L "$link_path" ]]; then
    rm "$link_path"
  elif [[ -e "$link_path" ]]; then
    echo "error: no-space source path already exists and is not a symlink: ${link_path}" >&2
    exit 66
  fi

  ln -s "$source_path" "$link_path"
}

prepare_no_space_build_env() {
  local build_root="${1:-}"
  if [[ -z "$build_root" ]]; then
    echo "error: --prepare-no-space-build-env requires a root path" >&2
    exit 64
  fi
  if path_contains_whitespace "$build_root"; then
    echo "error: --prepare-no-space-build-env root cannot contain whitespace: ${build_root}" >&2
    exit 64
  fi

  build_root="$(artifact_root_without_trailing_slash "$build_root")"
  local build_family
  build_family="$(apple_build_script_family)"

  mkdir -p \
    "${build_root}/sources" \
    "${build_root}/ffmpeg-${build_family}/build" \
    "${build_root}/ffmpeg-${build_family}/install" \
    "${build_root}/dav1d-${build_family}/build" \
    "${build_root}/dav1d-${build_family}/install" \
    "${build_root}/libbluray-${build_family}/build" \
    "${build_root}/libbluray-${build_family}/install" \
    "${build_root}/libdvdread-${build_family}/build" \
    "${build_root}/libdvdnav-${build_family}/build" \
    "${build_root}/deps/install" \
    "${build_root}/tools" \
    "${build_root}/python-tools"

  prepare_no_space_source_path "FFMPEG_SOURCE_DIR" "${build_root}/sources/ffmpeg"
  prepare_no_space_source_path "DAV1D_SOURCE_DIR" "${build_root}/sources/dav1d"
  prepare_no_space_source_path "LIBBLURAY_SOURCE_DIR" "${build_root}/sources/libbluray"
  prepare_no_space_source_path "LIBDVDREAD_SOURCE_DIR" "${build_root}/sources/libdvdread"
  prepare_no_space_source_path "LIBDVDNAV_SOURCE_DIR" "${build_root}/sources/libdvdnav"
  print_no_space_build_env "$build_root"
}

print_artifact_env() {
  local artifact_root="${1:-}"
  local slice_name="${2:-}"
  if [[ -z "$artifact_root" || -z "$slice_name" ]]; then
    echo "error: --print-artifact-env requires an artifact root and slice name" >&2
    exit 64
  fi

  require_artifact_slice_name "$slice_name"
  artifact_root="$(artifact_root_absolute_without_trailing_slash "$artifact_root")"
  adopt_artifact_manifest_configuration "$artifact_root"

  local resolved_prefixes
  resolved_prefixes="$(artifact_slice_prefixes_for_consumer "$artifact_root" "$slice_name")"
  local ffmpeg_prefix="${resolved_prefixes%%$'\n'*}"
  local dep_prefix=""
  if [[ "$resolved_prefixes" == *$'\n'* ]]; then
    dep_prefix="${resolved_prefixes#*$'\n'}"
  fi

  printf 'export NSURATOR_PLAYER_CORE_FFMPEG_PREFIX=%s\n' "$(shell_single_quote "$ffmpeg_prefix")"
  if [[ -n "${NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE:-}" ]]; then
    printf 'export NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE=%s\n' "$(shell_single_quote "$(ffmpeg_link_profile)")"
  fi
  if [[ -n "${NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE:-}" ]]; then
    printf 'export NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE=%s\n' "$(shell_single_quote "$(swiftpm_link_mode)")"
  fi

  if [[ -n "$dep_prefix" ]]; then
    printf 'export NSURATOR_PLAYER_CORE_DEP_PREFIX=%s\n' "$(shell_single_quote "$dep_prefix")"
  fi

  if [[ "$(swiftpm_link_mode)" == "framework" ]]; then
    local framework_relative_path
    framework_relative_path="$(read_artifact_slice_runtime_framework_relative_path "$artifact_root" "$slice_name")"
    if [[ -z "$framework_relative_path" ]]; then
      echo "error: framework artifact slice ${slice_name} does not declare runtimeFrameworkRelativePath" >&2
      exit 66
    fi
    case "$framework_relative_path" in
      /*|..|../*|*/../*|*/..)
        echo "error: runtime framework path must stay inside the artifact root: ${framework_relative_path}" >&2
        exit 66
        ;;
    esac
    local framework_path="${artifact_root}/${framework_relative_path}"
    if [[ ! -d "$framework_path" ]]; then
      echo "error: runtime framework is missing: ${framework_path}" >&2
      exit 66
    fi
    printf 'export NSURATOR_PLAYER_CORE_FFMPEG_FRAMEWORK_DIR=%s\n' "$(shell_single_quote "$(dirname "$framework_path")")"
  fi

  if network_protocols_enabled; then
    printf "export NSURATOR_PLAYER_CORE_ENABLE_NETWORK_PROTOCOLS='1'\n"
  fi
  local extra_runtime_libraries="${NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES:-}"
  if [[ -n "$extra_runtime_libraries" ]]; then
    printf 'export NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES=%s\n' "$(shell_single_quote "$extra_runtime_libraries")"
  fi
  local extra_ffmpeg_configure_flags="${NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS:-}"
  if [[ -n "$extra_ffmpeg_configure_flags" ]]; then
    printf 'export NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS=%s\n' "$(shell_single_quote "$extra_ffmpeg_configure_flags")"
  fi
}

xcconfig_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

xcconfig_include_flag() {
  local path="$1"
  printf '%s%s' "-I" "$(xcconfig_quote "$path")"
}

print_xcconfig() {
  local prefix="${1:-}"
  if [[ -z "$prefix" ]]; then
    echo "error: --print-xcconfig requires an install prefix" >&2
    exit 64
  fi

  local profile
  profile="$(ffmpeg_link_profile)"
  local other_cflags="\$(inherited) -DNPC_FFMPEG_CSHIM_ENABLE_LIBAV=1 -DNPC_FFMPEG_CSHIM_ENABLE_LIBBLURAY=1 $(xcconfig_include_flag "${prefix}/include")"
  if extra_runtime_library_enabled libsmb2; then
    other_cflags="${other_cflags} -DNPC_FFMPEG_CSHIM_ENABLE_LIBSMB2=1"
  fi
  if libnfs_custom_avio_enabled; then
    other_cflags="${other_cflags} -DNPC_FFMPEG_CSHIM_ENABLE_LIBNFS=1"
  fi
  if libdvdnav_shim_enabled; then
    other_cflags="${other_cflags} -DNPC_FFMPEG_CSHIM_ENABLE_LIBDVDNAV=1"
  fi
  local library_search_paths="\$(inherited) $(xcconfig_quote "${prefix}/lib")"
  local other_ldflags="\$(inherited) -lavfilter -lavformat -lavcodec -lavutil -lswresample -lswscale -lbluray"
  if [[ "$profile" == "full" ]]; then
    other_ldflags="${other_ldflags} -ldvdnav -ldvdread -ldav1d"
  fi
  other_ldflags="${other_ldflags} $(apple_framework_xcconfig_flags) -lz -lbz2 -liconv"
  local runtime_library
  if [[ "$profile" == "full" ]]; then
    for runtime_library in "${modern_video_runtime_libraries[@]}"; do
      other_ldflags="${other_ldflags} -l$(runtime_library_link_name "$runtime_library")"
    done
  fi

  local dep_prefix="${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}"
  if [[ -n "$dep_prefix" ]]; then
    other_cflags="${other_cflags} $(xcconfig_include_flag "${dep_prefix}/include")"
    library_search_paths="${library_search_paths} $(xcconfig_quote "${dep_prefix}/lib")"
  fi

  local dep_cflags="${NSURATOR_PLAYER_CORE_DEP_CFLAGS:-}"
  if [[ -n "$dep_cflags" ]]; then
    other_cflags="${other_cflags} ${dep_cflags}"
  fi

  local dep_ldflags="${NSURATOR_PLAYER_CORE_DEP_LDFLAGS:-}"
  if [[ -n "$dep_ldflags" ]]; then
    other_ldflags="${other_ldflags} ${dep_ldflags}"
  fi

  if network_protocols_enabled; then
    other_ldflags="${other_ldflags} -lsmbclient -lssh -lnfs -lsrt -lrist -lrtmp -lrabbitmq -lzmq -framework Security"
  fi
  while IFS= read -r runtime_library; do
    other_ldflags="${other_ldflags} -l$(runtime_library_link_name "$runtime_library")"
  done < <(extra_runtime_libraries)

  local extra_xcconfig_ldflags="${NSURATOR_PLAYER_CORE_EXTRA_XCCONFIG_LDFLAGS:-}"
  if [[ -n "$extra_xcconfig_ldflags" ]]; then
    other_ldflags="${other_ldflags} ${extra_xcconfig_ldflags}"
  fi

  cat <<XCCONFIG
// Generated by ${build_script_name} --print-xcconfig
OTHER_CFLAGS = ${other_cflags}
LIBRARY_SEARCH_PATHS = ${library_search_paths}
OTHER_LDFLAGS = ${other_ldflags}
XCCONFIG
}

print_xcconfig_settings_for_prefix() {
  local prefix="$1"
  local sdk_condition="$2"
  local dep_prefix="${3:-}"

  local profile
  profile="$(ffmpeg_link_profile)"
  local other_cflags="\$(inherited) -DNPC_FFMPEG_CSHIM_ENABLE_LIBAV=1 -DNPC_FFMPEG_CSHIM_ENABLE_LIBBLURAY=1 $(xcconfig_include_flag "${prefix}/include")"
  if extra_runtime_library_enabled libsmb2; then
    other_cflags="${other_cflags} -DNPC_FFMPEG_CSHIM_ENABLE_LIBSMB2=1"
  fi
  if libnfs_custom_avio_enabled; then
    other_cflags="${other_cflags} -DNPC_FFMPEG_CSHIM_ENABLE_LIBNFS=1"
  fi
  if libdvdnav_shim_enabled; then
    other_cflags="${other_cflags} -DNPC_FFMPEG_CSHIM_ENABLE_LIBDVDNAV=1"
  fi
  local library_search_paths="\$(inherited) $(xcconfig_quote "${prefix}/lib")"
  local other_ldflags="\$(inherited) -lavfilter -lavformat -lavcodec -lavutil -lswresample -lswscale -lbluray"
  if [[ "$profile" == "full" ]]; then
    other_ldflags="${other_ldflags} -ldvdnav -ldvdread -ldav1d"
  fi
  other_ldflags="${other_ldflags} $(apple_framework_xcconfig_flags) -lz -lbz2 -liconv"
  local runtime_library
  if [[ "$profile" == "full" ]]; then
    for runtime_library in "${modern_video_runtime_libraries[@]}"; do
      other_ldflags="${other_ldflags} -l$(runtime_library_link_name "$runtime_library")"
    done
  fi

  if [[ -n "$dep_prefix" ]]; then
    other_cflags="${other_cflags} $(xcconfig_include_flag "${dep_prefix}/include")"
    library_search_paths="${library_search_paths} $(xcconfig_quote "${dep_prefix}/lib")"
  fi

  local dep_cflags="${NSURATOR_PLAYER_CORE_DEP_CFLAGS:-}"
  if [[ -n "$dep_cflags" ]]; then
    other_cflags="${other_cflags} ${dep_cflags}"
  fi

  local dep_ldflags="${NSURATOR_PLAYER_CORE_DEP_LDFLAGS:-}"
  if [[ -n "$dep_ldflags" ]]; then
    other_ldflags="${other_ldflags} ${dep_ldflags}"
  fi

  if network_protocols_enabled; then
    other_ldflags="${other_ldflags} -lsmbclient -lssh -lnfs -lsrt -lrist -lrtmp -lrabbitmq -lzmq -framework Security"
  fi
  while IFS= read -r runtime_library; do
    other_ldflags="${other_ldflags} -l$(runtime_library_link_name "$runtime_library")"
  done < <(extra_runtime_libraries)

  local extra_xcconfig_ldflags="${NSURATOR_PLAYER_CORE_EXTRA_XCCONFIG_LDFLAGS:-}"
  if [[ -n "$extra_xcconfig_ldflags" ]]; then
    other_ldflags="${other_ldflags} ${extra_xcconfig_ldflags}"
  fi

  printf 'OTHER_CFLAGS[%s] = %s\n' "$sdk_condition" "$other_cflags"
  printf 'LIBRARY_SEARCH_PATHS[%s] = %s\n' "$sdk_condition" "$library_search_paths"
  printf 'OTHER_LDFLAGS[%s] = %s\n' "$sdk_condition" "$other_ldflags"
}

print_xcconfig_root() {
  local install_root="${1:-}"
  if [[ -z "$install_root" ]]; then
    echo "error: --print-xcconfig-root requires an install root" >&2
    exit 64
  fi

  local dep_root="${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}"

  cat <<XCCONFIG
// Generated by ${build_script_name} --print-xcconfig-root
XCCONFIG
  local slice_definition
  for slice_definition in $(selected_apple_build_slices); do
    local slice_name sdk target_triple expected_platform xcconfig_sdk_condition
    IFS='|' read -r slice_name sdk target_triple expected_platform xcconfig_sdk_condition <<< "$slice_definition"
    local dep_prefix=""
    if [[ -n "$dep_root" ]]; then
      dep_prefix="${dep_root}/${slice_name}"
    fi
    print_xcconfig_settings_for_prefix \
      "${install_root}/${slice_name}" \
      "$xcconfig_sdk_condition" \
      "$dep_prefix"
  done
}

print_artifact_xcconfig_root() {
  local artifact_root="${1:-}"
  if [[ -z "$artifact_root" ]]; then
    echo "error: --print-artifact-xcconfig-root requires an artifact root" >&2
    exit 64
  fi

  artifact_root="$(artifact_root_absolute_without_trailing_slash "$artifact_root")"
  adopt_artifact_manifest_configuration "$artifact_root"

  cat <<XCCONFIG
// Generated by ${build_script_name} --print-artifact-xcconfig-root
XCCONFIG
  local slice_definition
  for slice_definition in $(selected_apple_build_slices); do
    local slice_name sdk target_triple expected_platform xcconfig_sdk_condition
    IFS='|' read -r slice_name sdk target_triple expected_platform xcconfig_sdk_condition <<< "$slice_definition"
    local resolved_prefixes
    resolved_prefixes="$(artifact_slice_prefixes_for_consumer "$artifact_root" "$slice_name")"
    local ffmpeg_prefix="${resolved_prefixes%%$'\n'*}"
    local dep_prefix=""
    if [[ "$resolved_prefixes" == *$'\n'* ]]; then
      dep_prefix="${resolved_prefixes#*$'\n'}"
    fi
    print_xcconfig_settings_for_prefix \
      "$ffmpeg_prefix" \
      "$xcconfig_sdk_condition" \
      "$dep_prefix"
  done
}

artifact_xcconfig_portable_prefix() {
  local artifact_root
  artifact_root="$(artifact_root_absolute_without_trailing_slash "$1")"
  local prefix="${2:-}"
  if [[ -z "$prefix" ]]; then
    return 0
  fi
  if [[ "$prefix" == "$artifact_root" ]]; then
    printf '$(%s)' "$artifact_xcconfig_root_build_setting"
  elif [[ "$prefix" == "${artifact_root}/"* ]]; then
    printf '$(%s)/%s' "$artifact_xcconfig_root_build_setting" "${prefix#${artifact_root}/}"
  else
    printf '%s' "$prefix"
  fi
}

print_packaged_artifact_xcconfig_root() {
  local artifact_root="${1:-}"
  if [[ -z "$artifact_root" ]]; then
    echo "error: packaged artifact xcconfig requires an artifact root" >&2
    exit 64
  fi
  artifact_root="$(artifact_root_absolute_without_trailing_slash "$artifact_root")"
  adopt_artifact_manifest_configuration "$artifact_root"

  cat <<XCCONFIG
// Generated by ${build_script_name} for a relocatable packaged artifact.
// Set ${artifact_xcconfig_root_build_setting} to this extracted artifact directory.
XCCONFIG
  local slice_definition
  for slice_definition in $(selected_apple_build_slices); do
    local slice_name sdk target_triple expected_platform xcconfig_sdk_condition
    IFS='|' read -r slice_name sdk target_triple expected_platform xcconfig_sdk_condition <<< "$slice_definition"
    local resolved_prefixes
    resolved_prefixes="$(artifact_slice_prefixes_for_consumer "$artifact_root" "$slice_name")"
    local ffmpeg_prefix="${resolved_prefixes%%$'\n'*}"
    local dep_prefix=""
    if [[ "$resolved_prefixes" == *$'\n'* ]]; then
      dep_prefix="${resolved_prefixes#*$'\n'}"
    fi
    ffmpeg_prefix="$(artifact_xcconfig_portable_prefix "$artifact_root" "$ffmpeg_prefix")"
    if [[ -n "$dep_prefix" ]]; then
      dep_prefix="$(artifact_xcconfig_portable_prefix "$artifact_root" "$dep_prefix")"
    fi
    print_xcconfig_settings_for_prefix \
      "$ffmpeg_prefix" \
      "$xcconfig_sdk_condition" \
      "$dep_prefix"
  done
}

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '%s' "$value"
}

json_string() {
  printf '"'
  json_escape "$1"
  printf '"'
}

json_nullable_string() {
  local value="$1"
  if [[ -n "$value" ]]; then
    json_string "$value"
  else
    printf 'null'
  fi
}

json_string_array() {
  local first=1
  local emitted=" "
  local value
  printf '['
  for value in "$@"; do
    if [[ "$emitted" == *" ${value} "* ]]; then
      continue
    fi
    emitted="${emitted}${value} "
    if [[ $first -eq 0 ]]; then
      printf ', '
    fi
    first=0
    json_string "$value"
  done
  printf ']'
}

artifact_runtime_capabilities_json() {
  local runtime_capabilities="${NSURATOR_PLAYER_CORE_FFMPEG_RUNTIME_CAPABILITIES_JSON:-}"
  if [[ -z "$runtime_capabilities" ]]; then
    return 0
  fi
  printf '%s' "$runtime_capabilities" | python3 -c '
import json
import sys

payload = sys.stdin.read()
try:
    value = json.loads(payload)
except json.JSONDecodeError as error:
    print(f"error: NSURATOR_PLAYER_CORE_FFMPEG_RUNTIME_CAPABILITIES_JSON is not valid JSON: {error}", file=sys.stderr)
    sys.exit(64)
if not isinstance(value, dict):
    print("error: NSURATOR_PLAYER_CORE_FFMPEG_RUNTIME_CAPABILITIES_JSON must be a JSON object", file=sys.stderr)
    sys.exit(64)
print(json.dumps(value, separators=(",", ":")))
'
}

artifact_runtime_capabilities_manifest_entry() {
  local runtime_capabilities
  runtime_capabilities="$(artifact_runtime_capabilities_json)"
  if [[ -n "$runtime_capabilities" ]]; then
    printf '  "runtimeCapabilities": %s,\n' "$runtime_capabilities"
  fi
}

artifact_license_files_json() {
  local license_root="${NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_ROOT:-}"
  local license_relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_RELATIVE_PATH:-licenses}"
  python3 - "$license_root" "$license_relative_root" <<'PY'
import json
import os
import pathlib
import sys

license_root = sys.argv[1]
relative_root = sys.argv[2].strip().replace("\\", "/").strip("/")
if not license_root:
    print("[]")
    sys.exit(0)
if not os.path.isdir(license_root):
    print(f"error: artifact license root does not exist: {license_root}", file=sys.stderr)
    sys.exit(66)
if not relative_root or relative_root == "." or ".." in pathlib.PurePosixPath(relative_root).parts:
    print("error: artifact license relative path must stay inside the artifact root", file=sys.stderr)
    sys.exit(64)

root = pathlib.Path(license_root)
entries = []
for path in sorted(root.rglob("*"), key=lambda value: value.as_posix().lower()):
    if path.is_symlink():
        print(f"error: artifact license file must not be a symlink: {path}", file=sys.stderr)
        sys.exit(66)
    if not path.is_file():
        continue
    if path.stat().st_size <= 0:
        print(f"error: artifact license file is empty: {path}", file=sys.stderr)
        sys.exit(66)
    component, separator, _ = path.name.partition("-")
    component = component.strip()
    if not separator or not component:
        print(
            f"error: artifact license file must use <component>-<document>: {path.name}",
            file=sys.stderr,
        )
        sys.exit(66)
    relative_file = path.relative_to(root).as_posix()
    entries.append({
        "component": component,
        "relativePath": f"{relative_root}/{relative_file}",
    })

print(json.dumps(entries, separators=(",", ":")))
PY
}

artifact_distribution_support_files_json() {
  local distribution_root="${NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_ROOT:-}"
  local distribution_relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_RELATIVE_PATH:-distribution}"
  python3 - "$distribution_root" "$distribution_relative_root" <<'PY'
import json
import os
import pathlib
import sys

distribution_root = sys.argv[1]
relative_root = sys.argv[2].strip().replace("\\", "/").strip("/")
if not distribution_root:
    print("[]")
    sys.exit(0)
if not os.path.isdir(distribution_root):
    print(f"error: artifact distribution root does not exist: {distribution_root}", file=sys.stderr)
    sys.exit(66)
if not relative_root or relative_root == "." or ".." in pathlib.PurePosixPath(relative_root).parts:
    print("error: artifact distribution relative path must stay inside the artifact root", file=sys.stderr)
    sys.exit(64)

kind_by_directory = {
    "attribution": "attribution",
    "source-offer": "sourceOffer",
    "relink-instructions": "relinkInstructions",
    "relink-materials-manifest": "relinkMaterialsManifest",
}
root = pathlib.Path(distribution_root)
entries = []
for path in sorted(root.rglob("*"), key=lambda value: value.as_posix().lower()):
    if path.is_symlink():
        print(f"error: artifact distribution-support file must not be a symlink: {path}", file=sys.stderr)
        sys.exit(66)
    if not path.is_file():
        continue
    if path.stat().st_size <= 0:
        print(f"error: artifact distribution-support file is empty: {path}", file=sys.stderr)
        sys.exit(66)
    relative_file = path.relative_to(root)
    if len(relative_file.parts) < 2 or relative_file.parts[0] not in kind_by_directory:
        expected = ", ".join(f"{name}/" for name in kind_by_directory)
        print(
            f"error: artifact distribution-support file must be under one of {expected}: {relative_file}",
            file=sys.stderr,
        )
        sys.exit(66)
    entries.append({
        "kind": kind_by_directory[relative_file.parts[0]],
        "relativePath": f"{relative_root}/{relative_file.as_posix()}",
    })

print(json.dumps(entries, separators=(",", ":")))
PY
}

artifact_relative_path_for_slice() {
  local relative_root="${1%/}"
  local slice_name="$2"
  if [[ -z "$relative_root" ]]; then
    printf ''
  elif [[ "$relative_root" == "." ]]; then
    printf '%s' "$slice_name"
  else
    printf '%s/%s' "$relative_root" "$slice_name"
  fi
}

print_artifact_manifest_slice() {
  local slice_name="$1"
  local sdk="$2"
  local target_triple="$3"
  local expected_platform="$4"
  local xcconfig_sdk_condition="$5"
  local install_root="$6"
  local dep_root="$7"
  local install_relative_root="$8"
  local dep_relative_root="$9"
  local ffmpeg_prefix="${install_root}/${slice_name}"
  local dep_prefix=""
  if [[ -n "$dep_root" ]]; then
    dep_prefix="${dep_root}/${slice_name}"
  fi
  local ffmpeg_relative_prefix
  ffmpeg_relative_prefix="$(artifact_relative_path_for_slice "$install_relative_root" "$slice_name")"
  local dep_relative_prefix=""
  if [[ -n "$dep_root" ]]; then
    dep_relative_prefix="$(artifact_relative_path_for_slice "$dep_relative_root" "$slice_name")"
  fi
  local framework_fields=""
  local framework_dir=""
  if [[ "$(swiftpm_link_mode)" == "framework" ]]; then
    local framework_relative_root
    framework_relative_root="$(runtime_framework_relative_root)"
    local framework_root="${NSURATOR_PLAYER_CORE_ARTIFACT_FRAMEWORK_ROOT:-$(dirname "$install_root")/${framework_relative_root}}"
    framework_dir="${framework_root}/${slice_name}"
    local framework_relative_path="${framework_relative_root}/${slice_name}/${runtime_framework_name}.framework"
    local framework_binary="${framework_dir}/${runtime_framework_name}.framework/Versions/A/${runtime_framework_name}"
    framework_fields="
      \"runtimeFrameworkName\": $(json_string "$runtime_framework_name"),
      \"runtimeFrameworkRelativePath\": $(json_string "$framework_relative_path"),
      \"runtimeFrameworkInstallName\": $(json_string "$(runtime_framework_install_name)"),"
    if [[ -f "$framework_binary" ]]; then
      framework_fields="${framework_fields}
      \"runtimeFrameworkBinarySHA256\": $(json_string "$(runtime_framework_binary_sha256 "$framework_binary")"),
      \"runtimeFrameworkUUID\": $(json_string "$(runtime_framework_binary_uuid "$framework_binary")"),"
    fi
  fi
  local swiftpm_flags
  swiftpm_flags="$(NSURATOR_PLAYER_CORE_FFMPEG_FRAMEWORK_DIR="${framework_dir:-${NSURATOR_PLAYER_CORE_FFMPEG_FRAMEWORK_DIR:-}}" print_artifact_scoped_swiftpm_flags "$ffmpeg_prefix" "$dep_prefix")"
  local runtime_platform
  runtime_platform="$(runtime_platform_for_apple_sdk "$sdk")"

  cat <<JSON
    {
      "name": $(json_string "$slice_name"),
      "sdk": $(json_string "$sdk"),
      "runtimePlatform": $(json_string "$runtime_platform"),
      "targetTriple": $(json_string "$target_triple"),
      "expectedPlatform": $(json_string "$expected_platform"),
      "ffmpegPrefix": $(json_string "$ffmpeg_prefix"),
      "dependencyPrefix": $(json_nullable_string "$dep_prefix"),
      "ffmpegPrefixRelativePath": $(json_nullable_string "$ffmpeg_relative_prefix"),
      "dependencyPrefixRelativePath": $(json_nullable_string "$dep_relative_prefix"),
      "xcconfigSdkCondition": $(json_string "$xcconfig_sdk_condition"),${framework_fields}
      "swiftpmFlags": $(json_string "$swiftpm_flags"),
      "requiredRuntimeLibraries": $(json_string_array "${required_runtime_libraries[@]}"),
      "requiredConfigureFlags": $(json_string_array "${required_configure_flags[@]}")
    }
JSON
}

print_artifact_manifest_root() {
  local install_root="${1:-}"
  if [[ -z "$install_root" ]]; then
    echo "error: --print-artifact-manifest-root requires an install root" >&2
    exit 64
  fi

  local profile
  profile="$(ffmpeg_link_profile)"
  local swiftpm_link_mode_value
  swiftpm_link_mode_value="$(swiftpm_link_mode)"
  local dep_root="${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}"
  local install_relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_INSTALL_RELATIVE_PATH:-}"
  local dep_relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_DEP_RELATIVE_PATH:-}"
  if [[ -z "$dep_root" ]]; then
    dep_relative_root=""
  fi
  local network_enabled="false"
  if network_protocols_enabled; then
    network_enabled="true"
  fi
  local required_configure_flags=(
    "--enable-libbluray"
  )
  local required_runtime_libraries=(
    "libbluray"
  )
  if [[ "$profile" == "full" ]]; then
    required_configure_flags+=(
      "--enable-libdav1d"
      "--enable-libdvdnav"
      "--enable-libdvdread"
      "${modern_video_configure_flags[@]}"
    )
    required_runtime_libraries+=(
      "dav1d"
      "libdvdnav"
      "libdvdread"
      "${modern_video_runtime_libraries[@]}"
    )
  fi
  if network_protocols_enabled; then
    required_configure_flags+=("${network_protocol_configure_flags[@]}")
    required_runtime_libraries+=(
      "libsmbclient"
      "libssh"
      "libnfs"
      "libsrt"
      "librist"
      "librtmp"
      "librabbitmq"
      "libzmq"
    )
  fi
  local extra_ffmpeg_configure_flags="${NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS:-}"
  if [[ -n "$extra_ffmpeg_configure_flags" ]]; then
    local extra_configure_flags=()
    local extra_runtime_preflight_flag
    read -r -a extra_configure_flags <<< "$extra_ffmpeg_configure_flags"
    while IFS= read -r extra_runtime_preflight_flag; do
      required_configure_flags+=("$extra_runtime_preflight_flag")
    done < <(runtime_preflight_configure_flags "${extra_configure_flags[@]}")
  fi
  local runtime_library
  while IFS= read -r runtime_library; do
    required_runtime_libraries+=("$runtime_library")
  done < <(extra_runtime_libraries)

  cat <<JSON
{
  "schemaVersion": 1,
  "generator": $(json_string "$build_script_name"),
  "installRoot": $(json_string "$install_root"),
  "dependencyRoot": $(json_nullable_string "$dep_root"),
  "installRootRelativePath": $(json_nullable_string "$install_relative_root"),
  "dependencyRootRelativePath": $(json_nullable_string "$dep_relative_root"),
  "networkProtocolsEnabled": ${network_enabled},
  "linkProfile": $(json_string "$profile"),
  "swiftpmLinkMode": $(json_string "$swiftpm_link_mode_value"),
  "requiredRuntimeLibraries": $(json_string_array "${required_runtime_libraries[@]}"),
  "requiredConfigureFlags": $(json_string_array "${required_configure_flags[@]}"),
  "thirdPartyLicenseFiles": $(artifact_license_files_json),
  "distributionSupportFiles": $(artifact_distribution_support_files_json),
$(artifact_runtime_capabilities_manifest_entry)
  "slices": [
JSON
  local first_slice=1
  local slice_definition
  for slice_definition in $(selected_apple_build_slices); do
    local slice_name sdk target_triple expected_platform xcconfig_sdk_condition
    IFS='|' read -r slice_name sdk target_triple expected_platform xcconfig_sdk_condition <<< "$slice_definition"
    if [[ "$first_slice" == "0" ]]; then
      printf ',\n'
    fi
    first_slice=0
    print_artifact_manifest_slice \
      "$slice_name" \
      "$sdk" \
      "$target_triple" \
      "$expected_platform" \
      "$xcconfig_sdk_condition" \
      "$install_root" \
      "$dep_root" \
      "$install_relative_root" \
      "$dep_relative_root"
  done
  cat <<JSON
  ]
}
JSON
}

package_artifact_root() {
  local artifact_root="${1:-}"
  local install_root="${2:-}"
  if [[ -z "$artifact_root" || -z "$install_root" ]]; then
    echo "error: --package-artifact-root requires an artifact root and install root" >&2
    exit 64
  fi

  artifact_root="$(artifact_root_without_trailing_slash "$artifact_root")"
  install_root="$(artifact_root_without_trailing_slash "$install_root")"
  if [[ ! -d "$install_root" ]]; then
    echo "error: install root does not exist: ${install_root}" >&2
    exit 66
  fi

  local source_dependency_root="${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}"
  if [[ -n "$source_dependency_root" ]]; then
    source_dependency_root="$(artifact_root_without_trailing_slash "$source_dependency_root")"
    if [[ ! -d "$source_dependency_root" ]]; then
      echo "error: dependency root does not exist: ${source_dependency_root}" >&2
      exit 66
    fi
  fi

  local install_relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_INSTALL_RELATIVE_PATH:-install}"
  local dependency_relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_DEP_RELATIVE_PATH:-dependencies}"
  local license_relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_RELATIVE_PATH:-licenses}"
  local distribution_relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_RELATIVE_PATH:-distribution}"
  case "$license_relative_root" in
    ""|"."|/*|".."|../*|*/../*|*/..)
      echo "error: artifact license relative path must stay inside the artifact root" >&2
      exit 64
      ;;
  esac
  license_relative_root="${license_relative_root#./}"
  license_relative_root="${license_relative_root%/}"
  case "$distribution_relative_root" in
    ""|"."|/*|".."|../*|*/../*|*/..)
      echo "error: artifact distribution relative path must stay inside the artifact root" >&2
      exit 64
      ;;
  esac
  distribution_relative_root="${distribution_relative_root#./}"
  distribution_relative_root="${distribution_relative_root%/}"
  if [[ "$distribution_relative_root" == "$install_relative_root" ||
        "$distribution_relative_root" == "$dependency_relative_root" ||
        "$distribution_relative_root" == "$license_relative_root" ]]; then
    echo "error: artifact distribution relative path must be distinct from install, dependency, and license roots" >&2
    exit 64
  fi
  local packaged_install_root="${artifact_root}/${install_relative_root}"
  local packaged_dependency_root=""
  if [[ -n "$source_dependency_root" ]]; then
    packaged_dependency_root="${artifact_root}/${dependency_relative_root}"
  fi
  local packaged_license_root="${artifact_root}/${license_relative_root}"
  local packaged_distribution_root="${artifact_root}/${distribution_relative_root}"
  local inferred_source_artifact_root=""
  if [[ "$install_root" == */"$install_relative_root" ]]; then
    inferred_source_artifact_root="${install_root:0:${#install_root}-${#install_relative_root}-1}"
  fi
  local packaged_license_root_absolute
  packaged_license_root_absolute="$(artifact_root_absolute_without_trailing_slash "$packaged_license_root")"
  local source_license_root="${NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_SOURCE_DIR:-}"
  if [[ -z "$source_license_root" &&
        -n "$inferred_source_artifact_root" &&
        -d "${inferred_source_artifact_root}/${license_relative_root}" ]]; then
    source_license_root="${inferred_source_artifact_root}/${license_relative_root}"
  fi
  if [[ -n "$source_license_root" ]]; then
    source_license_root="$(artifact_root_absolute_without_trailing_slash "$source_license_root")"
    if [[ ! -d "$source_license_root" ]]; then
      echo "error: artifact license source directory does not exist: ${source_license_root}" >&2
      exit 66
    fi
  fi
  local packaged_distribution_root_absolute
  packaged_distribution_root_absolute="$(artifact_root_absolute_without_trailing_slash "$packaged_distribution_root")"
  local source_distribution_root="${NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_SOURCE_DIR:-}"
  if [[ -z "$source_distribution_root" &&
        -n "$inferred_source_artifact_root" &&
        -d "${inferred_source_artifact_root}/${distribution_relative_root}" ]]; then
    source_distribution_root="${inferred_source_artifact_root}/${distribution_relative_root}"
  fi
  if [[ -n "$source_distribution_root" ]]; then
    source_distribution_root="$(artifact_root_absolute_without_trailing_slash "$source_distribution_root")"
    if [[ ! -d "$source_distribution_root" ]]; then
      echo "error: artifact distribution source directory does not exist: ${source_distribution_root}" >&2
      exit 66
    fi
  fi

  local framework_relative_root
  framework_relative_root="$(runtime_framework_relative_root)"
  local packaged_framework_root="${artifact_root}/${framework_relative_root}"

  mkdir -p "$artifact_root"
  rm -rf \
    "$packaged_install_root" \
    "$packaged_framework_root" \
    "${artifact_root}/NsuratorPlayerCoreFFmpeg.xcconfig" \
    "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json" \
    "${artifact_root}/nsurator-player-core-ffmpeg-visionos-manifest.json"
  if [[ -n "$packaged_dependency_root" ]]; then
    rm -rf "$packaged_dependency_root"
  fi

  mkdir -p "$(dirname "$packaged_install_root")"
  rsync -a "${install_root}/" "${packaged_install_root}/"
  if [[ -n "$packaged_dependency_root" ]]; then
    mkdir -p "$(dirname "$packaged_dependency_root")"
    rsync -a "${source_dependency_root}/" "${packaged_dependency_root}/"
  fi
  if [[ -z "$source_license_root" ]]; then
    rm -rf "$packaged_license_root"
  elif [[ "$source_license_root" != "$packaged_license_root_absolute" ]]; then
    rm -rf "$packaged_license_root"
    mkdir -p "$packaged_license_root"
    rsync -a "${source_license_root}/" "${packaged_license_root}/"
  fi
  if [[ -z "$source_distribution_root" ]]; then
    rm -rf "$packaged_distribution_root"
  elif [[ "$source_distribution_root" != "$packaged_distribution_root_absolute" ]]; then
    rm -rf "$packaged_distribution_root"
    mkdir -p "$packaged_distribution_root"
    rsync -a "${source_distribution_root}/" "${packaged_distribution_root}/"
  fi

  if [[ "$(swiftpm_link_mode)" == "framework" ]]; then
    local framework_slice_definition
    for framework_slice_definition in $(selected_apple_build_slices); do
      local framework_slice_name framework_sdk framework_target_triple
      IFS='|' read -r framework_slice_name framework_sdk framework_target_triple _ <<< "$framework_slice_definition"
      if [[ "$framework_sdk" != "macosx" ]]; then
        echo "error: framework link mode packages macOS slices only, not ${framework_slice_name}" >&2
        exit 64
      fi
      local framework_dependency_prefix=""
      if [[ -n "$packaged_dependency_root" ]]; then
        framework_dependency_prefix="${packaged_dependency_root}/${framework_slice_name}"
      fi
      "$(runtime_framework_packager)" --build \
        --ffmpeg-prefix "${packaged_install_root}/${framework_slice_name}" \
        ${framework_dependency_prefix:+--dependency-prefix "$framework_dependency_prefix"} \
        --output-dir "${packaged_framework_root}/${framework_slice_name}" \
        --sdk "$framework_sdk" \
        --target-triple "$framework_target_triple" \
        --record-root "$artifact_root"
    done
  fi

  (
    export NSURATOR_PLAYER_CORE_ARTIFACT_INSTALL_RELATIVE_PATH="$install_relative_root"
    if [[ -d "$packaged_framework_root" ]]; then
      export NSURATOR_PLAYER_CORE_ARTIFACT_FRAMEWORK_ROOT="$(artifact_root_absolute_without_trailing_slash "$packaged_framework_root")"
    else
      unset NSURATOR_PLAYER_CORE_ARTIFACT_FRAMEWORK_ROOT
    fi
    export NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_RELATIVE_PATH="$license_relative_root"
    if [[ -d "$packaged_license_root" ]]; then
      export NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_ROOT="$packaged_license_root"
    else
      unset NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_ROOT
    fi
    export NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_RELATIVE_PATH="$distribution_relative_root"
    if [[ -d "$packaged_distribution_root" ]]; then
      export NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_ROOT="$packaged_distribution_root"
    else
      unset NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_ROOT
    fi
    if [[ -n "$packaged_dependency_root" ]]; then
      export NSURATOR_PLAYER_CORE_DEP_PREFIX="$packaged_dependency_root"
      export NSURATOR_PLAYER_CORE_ARTIFACT_DEP_RELATIVE_PATH="$dependency_relative_root"
    else
      unset NSURATOR_PLAYER_CORE_DEP_PREFIX
      unset NSURATOR_PLAYER_CORE_ARTIFACT_DEP_RELATIVE_PATH
    fi
    print_artifact_manifest_root "$packaged_install_root" > "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json"
    print_packaged_artifact_xcconfig_root "$artifact_root" > "${artifact_root}/NsuratorPlayerCoreFFmpeg.xcconfig"
  )
  cp \
    "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json" \
    "${artifact_root}/nsurator-player-core-ffmpeg-visionos-manifest.json"

  echo "Packaged FFmpeg Apple artifact root: ${artifact_root}"
}

embed_artifact_runtime_capabilities() {
  local artifact_root="${1:-}"
  if [[ -z "$artifact_root" ]]; then
    echo "error: --embed-artifact-runtime-capabilities requires an artifact root" >&2
    exit 64
  fi
  if [[ -z "${NSURATOR_PLAYER_CORE_FFMPEG_RUNTIME_CAPABILITIES_JSON:-}" ]]; then
    echo "error: NSURATOR_PLAYER_CORE_FFMPEG_RUNTIME_CAPABILITIES_JSON is required for --embed-artifact-runtime-capabilities" >&2
    exit 64
  fi

  artifact_root="$(artifact_root_without_trailing_slash "$artifact_root")"
  if [[ ! -d "$artifact_root" ]]; then
    echo "error: artifact root does not exist: ${artifact_root}" >&2
    exit 66
  fi

  local install_relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_INSTALL_RELATIVE_PATH:-install}"
  local dependency_relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_DEP_RELATIVE_PATH:-dependencies}"
  local license_relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_RELATIVE_PATH:-licenses}"
  local distribution_relative_root="${NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_RELATIVE_PATH:-distribution}"
  local packaged_install_root="${artifact_root}/${install_relative_root}"
  local packaged_dependency_root="${artifact_root}/${dependency_relative_root}"
  local packaged_license_root="${artifact_root}/${license_relative_root}"
  local packaged_distribution_root="${artifact_root}/${distribution_relative_root}"
  if [[ ! -d "$packaged_install_root" ]]; then
    echo "error: artifact install root does not exist: ${packaged_install_root}" >&2
    exit 66
  fi

  local packaged_framework_root
  packaged_framework_root="${artifact_root}/$(runtime_framework_relative_root)"
  local tmp_manifest="${artifact_root}/.nsurator-player-core-ffmpeg-apple-manifest.json.tmp"
  (
    export NSURATOR_PLAYER_CORE_ARTIFACT_INSTALL_RELATIVE_PATH="$install_relative_root"
    if [[ -d "$packaged_framework_root" ]]; then
      export NSURATOR_PLAYER_CORE_ARTIFACT_FRAMEWORK_ROOT="$(artifact_root_absolute_without_trailing_slash "$packaged_framework_root")"
    else
      unset NSURATOR_PLAYER_CORE_ARTIFACT_FRAMEWORK_ROOT
    fi
    export NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_RELATIVE_PATH="$license_relative_root"
    if [[ -d "$packaged_license_root" ]]; then
      export NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_ROOT="$packaged_license_root"
    else
      unset NSURATOR_PLAYER_CORE_ARTIFACT_LICENSE_ROOT
    fi
    export NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_RELATIVE_PATH="$distribution_relative_root"
    if [[ -d "$packaged_distribution_root" ]]; then
      export NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_ROOT="$packaged_distribution_root"
    else
      unset NSURATOR_PLAYER_CORE_ARTIFACT_DISTRIBUTION_ROOT
    fi
    if [[ -d "$packaged_dependency_root" ]]; then
      export NSURATOR_PLAYER_CORE_DEP_PREFIX="$packaged_dependency_root"
      export NSURATOR_PLAYER_CORE_ARTIFACT_DEP_RELATIVE_PATH="$dependency_relative_root"
    else
      unset NSURATOR_PLAYER_CORE_DEP_PREFIX
      unset NSURATOR_PLAYER_CORE_ARTIFACT_DEP_RELATIVE_PATH
    fi
    print_artifact_manifest_root "$packaged_install_root" > "$tmp_manifest"
  )
  mv "$tmp_manifest" "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json"
  cp \
    "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json" \
    "${artifact_root}/nsurator-player-core-ffmpeg-visionos-manifest.json"

  echo "Embedded FFmpeg runtime capabilities into artifact manifest: ${artifact_root}"
}

artifact_exists_in_prefixes() {
  local relative_path="$1"
  shift
  local prefix
  for prefix in "$@"; do
    if [[ -n "$prefix" && -f "${prefix}/${relative_path}" ]]; then
      return 0
    fi
  done
  return 1
}

artifact_path_in_prefixes() {
  local relative_path="$1"
  shift
  local prefix
  for prefix in "$@"; do
    if [[ -n "$prefix" && -f "${prefix}/${relative_path}" ]]; then
      printf '%s\n' "${prefix}/${relative_path}"
      return 0
    fi
  done
  return 1
}

verify_static_library_platform() {
  local library_path="$1"
  local expected_platform="$2"
  local archs
  archs="$(xcrun lipo -archs "$library_path" 2>/dev/null || true)"
  if [[ " ${archs} " != *" arm64 "* ]]; then
    echo "error: wrong architecture for ${library_path}: expected arm64, got ${archs:-unknown}" >&2
    return 1
  fi

  local member_dir
  member_dir="$(mktemp -d)"
  (
    cd "$member_dir"
    ar -x "$library_path"
  )

  local member
  local found_macho_member=0
  local invalid_member=0
  while IFS= read -r -d '' member; do
    local build_info
    build_info="$(xcrun vtool -show-build "$member" 2>/dev/null || true)"
    if [[ "$build_info" == *"platform "* ]]; then
      found_macho_member=1
      if [[ "$build_info" != *"platform ${expected_platform}"* ]]; then
        echo "error: wrong platform for ${library_path}: expected ${expected_platform}" >&2
        echo "$build_info" >&2
        invalid_member=1
        break
      fi
    fi
  done < <(find "$member_dir" -type f -print0)
  rm -rf "$member_dir"

  if [[ "$invalid_member" == "1" ]]; then
    return 1
  fi
  if [[ "$found_macho_member" == "0" ]]; then
    echo "error: no Mach-O members found in ${library_path}" >&2
    return 1
  fi
  return 0
}

verify_install() {
  local prefix="${1:-}"
  local expected_platform="${2:-}"
  local dep_prefix="${3:-${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}}"
  if [[ -z "$prefix" ]]; then
    echo "error: --verify-install requires an install prefix" >&2
    exit 64
  fi

  local dependency_prefixes=("$prefix")
  if [[ -n "$dep_prefix" ]]; then
    dependency_prefixes+=("$dep_prefix")
  fi

  local missing=()
  local ffmpeg_headers=(
    "include/libavfilter/avfilter.h"
    "include/libavformat/avformat.h"
    "include/libavcodec/avcodec.h"
    "include/libavutil/avutil.h"
    "include/libswresample/swresample.h"
    "include/libswscale/swscale.h"
  )
  local ffmpeg_libraries=(
    "lib/libavfilter.a"
    "lib/libavformat.a"
    "lib/libavcodec.a"
    "lib/libavutil.a"
    "lib/libswresample.a"
    "lib/libswscale.a"
  )
  local profile
  profile="$(ffmpeg_link_profile)"
  local dependency_artifacts=(
    "include/libbluray/bluray.h"
    "lib/libbluray.a"
  )
  if [[ "$profile" == "full" ]]; then
    dependency_artifacts+=(
      "include/dvdnav/dvdnav.h"
      "lib/libdvdnav.a"
      "include/dvdread/dvd_reader.h"
      "lib/libdvdread.a"
      "include/dav1d/dav1d.h"
      "lib/libdav1d.a"
      "include/vvdec/vvdec.h"
      "lib/libvvdec.a"
      "include/xevd.h"
      "lib/libxevd.a"
      "include/davs2.h"
      "lib/libdavs2.a"
      "include/uavs3d.h"
      "lib/libuavs3d.a"
      "include/openjpeg-2.5/openjpeg.h"
      "lib/libopenjpeg.a"
      "include/SvtJpegxsDec.h"
      "lib/libsvtjpegxs.a"
      "include/jxl/decode.h"
      "lib/libjxl.a"
      "include/vpx/vpx_decoder.h"
      "lib/libvpx.a"
    )
  fi

  if network_protocols_enabled; then
    dependency_artifacts+=(
      "include/libsmbclient.h"
      "lib/libsmbclient.a"
      "include/libssh/sftp.h"
      "lib/libssh.a"
      "include/nfsc/libnfs.h"
      "lib/libnfs.a"
      "include/srt/srt.h"
      "lib/libsrt.a"
      "include/librist/librist.h"
      "lib/librist.a"
      "include/librtmp/rtmp.h"
      "lib/librtmp.a"
      "include/amqp.h"
      "lib/librabbitmq.a"
      "include/zmq.h"
      "lib/libzmq.a"
    )
  fi
  local runtime_library
  local runtime_library_header
  while IFS= read -r runtime_library; do
    runtime_library_header="$(runtime_library_header_artifact "$runtime_library")"
    if [[ -n "$runtime_library_header" ]]; then
      dependency_artifacts+=("$runtime_library_header")
    fi
    dependency_artifacts+=("$(runtime_library_static_artifact "$runtime_library")")
  done < <(extra_runtime_libraries)

  local artifact
  for artifact in "${ffmpeg_headers[@]}" "${ffmpeg_libraries[@]}"; do
    if [[ ! -f "${prefix}/${artifact}" ]]; then
      missing+=("$artifact")
    fi
  done

  for artifact in "${dependency_artifacts[@]}"; do
    if ! artifact_exists_in_prefixes "$artifact" "${dependency_prefixes[@]}"; then
      missing+=("$artifact")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "error: missing required FFmpeg/libbluray install artifacts:" >&2
    for artifact in "${missing[@]}"; do
      echo "  ${artifact}" >&2
    done
    exit 66
  fi

  if [[ -n "$expected_platform" ]]; then
    local invalid_libraries=()
    local library_artifacts=("${ffmpeg_libraries[@]}" "${dependency_artifacts[@]}")
    for artifact in "${library_artifacts[@]}"; do
      if [[ "$artifact" != lib/*.a ]]; then
        continue
      fi
      local artifact_path
      artifact_path="$(artifact_path_in_prefixes "$artifact" "${dependency_prefixes[@]}")"
      if [[ -n "$artifact_path" ]] &&
          ! verify_static_library_platform "$artifact_path" "$expected_platform"; then
        invalid_libraries+=("$artifact")
      fi
    done
    if [[ ${#invalid_libraries[@]} -gt 0 ]]; then
      echo "error: invalid or wrong-platform static libraries for ${expected_platform}:" >&2
      for artifact in "${invalid_libraries[@]}"; do
        echo "  ${artifact}" >&2
      done
      exit 66
    fi
  fi

  echo "Verified FFmpeg Apple install prefix: ${prefix}"
  if [[ -n "$dep_prefix" ]]; then
    echo "Verified FFmpeg Apple dependency prefix: ${dep_prefix}"
  fi
}

verify_install_root() {
  local install_root="${1:-}"
  if [[ -z "$install_root" ]]; then
    echo "error: --verify-install-root requires an install root" >&2
    exit 64
  fi

  local slice_definition
  for slice_definition in $(selected_apple_build_slices); do
    local slice_name sdk target_triple expected_platform xcconfig_sdk_condition
    IFS='|' read -r slice_name sdk target_triple expected_platform xcconfig_sdk_condition <<< "$slice_definition"
    echo "# Verifying ${slice_name}"
    local slice_dep_prefix=""
    if [[ -n "${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}" ]]; then
      slice_dep_prefix="$(dependency_prefix_for_slice "$slice_name")"
    fi
    verify_install "${install_root}/${slice_name}" "$expected_platform" "$slice_dep_prefix"
  done
  echo "Verified FFmpeg Apple install root: ${install_root}"
}

xcconfig_sdk_condition_for_slice() {
  local slice_name="$1"
  local slice_definition
  for slice_definition in "${apple_build_slices[@]}"; do
    local known_slice_name sdk target_triple expected_platform xcconfig_sdk_condition
    IFS='|' read -r known_slice_name sdk target_triple expected_platform xcconfig_sdk_condition <<< "$slice_definition"
    if [[ "$slice_name" == "$known_slice_name" ]]; then
      printf '%s' "$xcconfig_sdk_condition"
      return 0
    fi
  done
  return 1
}

artifact_xcconfig_setting_line() {
  local xcconfig_path="$1"
  local setting_name="$2"
  local sdk_condition="$3"
  awk -v key="${setting_name}[${sdk_condition}]" '
    index($0, key) == 1 {
      line = $0
      found = 1
    }
    END {
      if (!found) {
        exit 1
      }
      print line
    }
  ' "$xcconfig_path"
}

artifact_xcconfig_include_flag_present() {
  local line="$1"
  local artifact_root="$2"
  local include_path="$3"
  local portable_include_path
  portable_include_path="$(artifact_xcconfig_portable_prefix "$artifact_root" "$include_path")"
  local candidate
  for candidate in "$include_path" "$portable_include_path"; do
    local quoted_flag
    quoted_flag="$(xcconfig_include_flag "$candidate")"
    if [[ "$line" == *"$quoted_flag"* ]]; then
      return 0
    fi
    if ! path_contains_whitespace "$candidate" &&
        [[ "$candidate" != *'$('* && "$line" == *"-I${candidate}"* ]]; then
      return 0
    fi
  done
  return 1
}

artifact_xcconfig_path_present() {
  local line="$1"
  local artifact_root="$2"
  local path="$3"
  local portable_path
  portable_path="$(artifact_xcconfig_portable_prefix "$artifact_root" "$path")"
  local candidate
  for candidate in "$path" "$portable_path"; do
    if [[ "$line" == *"\"${candidate}\""* ]]; then
      return 0
    fi
    if ! path_contains_whitespace "$candidate" &&
        [[ "$candidate" != *'$('* && "$line" == *"$candidate"* ]]; then
      return 0
    fi
  done
  return 1
}

verify_artifact_xcconfig_settings() {
  local artifact_root="$1"
  local slice_name="$2"
  local ffmpeg_prefix="$3"
  local dependency_prefix="$4"
  local xcconfig_path="${artifact_root}/NsuratorPlayerCoreFFmpeg.xcconfig"
  local sdk_condition
  if ! sdk_condition="$(xcconfig_sdk_condition_for_slice "$slice_name")"; then
    echo "error: unknown artifact slice for Xcode xcconfig verification: ${slice_name}" >&2
    exit 66
  fi

  local missing=()
  if [[ ! -f "$xcconfig_path" ]]; then
    missing+=("NsuratorPlayerCoreFFmpeg.xcconfig")
  else
    local other_cflags_line=""
    if ! other_cflags_line="$(artifact_xcconfig_setting_line "$xcconfig_path" "OTHER_CFLAGS" "$sdk_condition")"; then
      missing+=("OTHER_CFLAGS[${sdk_condition}]")
    else
      local required_cflag
      local required_cflags=(
        "-DNPC_FFMPEG_CSHIM_ENABLE_LIBAV=1"
        "-DNPC_FFMPEG_CSHIM_ENABLE_LIBBLURAY=1"
      )
      if extra_runtime_library_enabled libsmb2; then
        required_cflags+=("-DNPC_FFMPEG_CSHIM_ENABLE_LIBSMB2=1")
      fi
      if libnfs_custom_avio_enabled; then
        required_cflags+=("-DNPC_FFMPEG_CSHIM_ENABLE_LIBNFS=1")
      fi
      for required_cflag in "${required_cflags[@]}"; do
        if [[ "$other_cflags_line" != *"$required_cflag"* ]]; then
          missing+=("OTHER_CFLAGS[${sdk_condition}] ${required_cflag}")
        fi
      done
      local required_include_path
      local required_include_paths=("${ffmpeg_prefix}/include")
      if [[ -n "$dependency_prefix" ]]; then
        required_include_paths+=("${dependency_prefix}/include")
      fi
      for required_include_path in "${required_include_paths[@]}"; do
        if ! artifact_xcconfig_include_flag_present \
          "$other_cflags_line" \
          "$artifact_root" \
          "$required_include_path"; then
          missing+=("OTHER_CFLAGS[${sdk_condition}] $(xcconfig_include_flag "$required_include_path")")
        fi
      done
    fi

    local library_search_paths_line=""
    if ! library_search_paths_line="$(artifact_xcconfig_setting_line "$xcconfig_path" "LIBRARY_SEARCH_PATHS" "$sdk_condition")"; then
      missing+=("LIBRARY_SEARCH_PATHS[${sdk_condition}]")
    else
      local required_library_search_path
      local required_library_search_paths=("${ffmpeg_prefix}/lib")
      if [[ -n "$dependency_prefix" ]]; then
        required_library_search_paths+=("${dependency_prefix}/lib")
      fi
      for required_library_search_path in "${required_library_search_paths[@]}"; do
        if ! artifact_xcconfig_path_present \
          "$library_search_paths_line" \
          "$artifact_root" \
          "$required_library_search_path"; then
          missing+=("LIBRARY_SEARCH_PATHS[${sdk_condition}] ${required_library_search_path}")
        fi
      done
    fi

    local other_ldflags_line=""
    if ! other_ldflags_line="$(artifact_xcconfig_setting_line "$xcconfig_path" "OTHER_LDFLAGS" "$sdk_condition")"; then
      missing+=("OTHER_LDFLAGS[${sdk_condition}]")
    else
      local profile
      profile="$(ffmpeg_link_profile)"
      local required_ldflags=(
        "-lavfilter"
        "-lavformat"
        "-lavcodec"
        "-lavutil"
        "-lswresample"
        "-lswscale"
        "-lbluray"
      )
      if [[ "$profile" == "full" ]]; then
        required_ldflags+=("-ldvdnav" "-ldvdread" "-ldav1d")
        local modern_video_runtime_library
        for modern_video_runtime_library in "${modern_video_runtime_libraries[@]}"; do
          required_ldflags+=("-l$(runtime_library_link_name "$modern_video_runtime_library")")
        done
      fi
      if network_protocols_enabled; then
        required_ldflags+=(
          "-lsmbclient"
          "-lssh"
          "-lnfs"
          "-lsrt"
          "-lrist"
          "-lrtmp"
          "-lrabbitmq"
          "-lzmq"
        )
      fi
      local runtime_library
      while IFS= read -r runtime_library; do
        if [[ -n "$runtime_library" ]]; then
          required_ldflags+=("-l$(runtime_library_link_name "$runtime_library")")
        fi
      done < <(extra_runtime_libraries)

      local required_ldflag
      for required_ldflag in "${required_ldflags[@]}"; do
        if [[ "$other_ldflags_line" != *"$required_ldflag"* ]]; then
          missing+=("OTHER_LDFLAGS[${sdk_condition}] ${required_ldflag}")
        fi
      done
    fi
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "error: missing required Apple artifact Xcode xcconfig settings:" >&2
    local item
    for item in "${missing[@]}"; do
      echo "  ${item}" >&2
    done
    exit 66
  fi
}

artifact_manifest_path_for_root() {
  local artifact_root="$1"
  local manifest_path
  for manifest_path in \
    "${artifact_root}/nsurator-player-core-ffmpeg-apple-manifest.json" \
    "${artifact_root}/nsurator-player-core-ffmpeg-visionos-manifest.json"; do
    if [[ -f "$manifest_path" ]]; then
      printf '%s' "$manifest_path"
      return 0
    fi
  done

  echo "error: missing Apple FFmpeg artifact manifest under ${artifact_root}" >&2
  exit 66
}

artifact_path_from_relative() {
  local artifact_root="$1"
  local relative_path="$2"
  if [[ -z "$relative_path" ]]; then
    return 0
  fi
  if [[ "$relative_path" == /* ]]; then
    printf '%s' "$relative_path"
    return 0
  fi
  relative_path="${relative_path#./}"
  if [[ "$relative_path" == "." ]]; then
    printf '%s' "$artifact_root"
  else
    printf '%s/%s' "$artifact_root" "$relative_path"
  fi
}

artifact_manifest_slice_rows() {
  local manifest_path="$1"
  python3 - "$manifest_path" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

slices = manifest.get("slices")
if not isinstance(slices, list) or not slices:
    print("error: artifact manifest has no slices", file=sys.stderr)
    sys.exit(66)

for slice_manifest in slices:
    if not isinstance(slice_manifest, dict):
        print("error: artifact manifest slice entries must be objects", file=sys.stderr)
        sys.exit(66)
    name = slice_manifest.get("name") or ""
    if not isinstance(name, str) or not name:
        print("error: artifact manifest slice is missing a name", file=sys.stderr)
        sys.exit(66)

    def field(key):
        value = slice_manifest.get(key)
        if isinstance(value, str):
            return value
        return ""

    print("\t".join([
        name,
        field("expectedPlatform"),
        field("ffmpegPrefixRelativePath"),
        field("dependencyPrefixRelativePath"),
        field("ffmpegPrefix"),
        field("dependencyPrefix"),
    ]))
PY
}

verify_artifact_distribution_licenses() {
  local artifact_root="$1"
  local manifest_path="$2"
  local require_release_coverage="${3:-0}"
  python3 - "$artifact_root" "$manifest_path" "$require_release_coverage" <<'PY'
import json
import os
import re
import sys

artifact_root = os.path.realpath(sys.argv[1])
manifest_path = sys.argv[2]
require_release_coverage = sys.argv[3] == "1"
with open(manifest_path, "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

entries = manifest.get("thirdPartyLicenseFiles")
if entries is None:
    entries = []
if not isinstance(entries, list):
    print("error: artifact manifest thirdPartyLicenseFiles must be an array", file=sys.stderr)
    sys.exit(66)
if require_release_coverage and not entries:
    print("error: release artifact has no declared third-party license files", file=sys.stderr)
    sys.exit(66)

components = {}
for entry in entries:
    if not isinstance(entry, dict):
        print("error: artifact license entries must be objects", file=sys.stderr)
        sys.exit(66)
    component = entry.get("component")
    relative_path = entry.get("relativePath")
    if not isinstance(component, str) or not component.strip():
        print("error: artifact license entry is missing a component", file=sys.stderr)
        sys.exit(66)
    if not isinstance(relative_path, str) or not relative_path.strip():
        print("error: artifact license entry is missing a relativePath", file=sys.stderr)
        sys.exit(66)
    if os.path.isabs(relative_path):
        print(f"error: artifact license path must be relative: {relative_path}", file=sys.stderr)
        sys.exit(66)
    resolved_path = os.path.realpath(os.path.join(artifact_root, relative_path))
    try:
        common_root = os.path.commonpath([artifact_root, resolved_path])
    except ValueError:
        common_root = ""
    if common_root != artifact_root:
        print(f"error: artifact license path escapes the artifact root: {relative_path}", file=sys.stderr)
        sys.exit(66)
    if not os.path.isfile(resolved_path):
        print(f"error: declared artifact license file is missing: {relative_path}", file=sys.stderr)
        sys.exit(66)
    if os.path.getsize(resolved_path) <= 0:
        print(f"error: declared artifact license file is empty: {relative_path}", file=sys.stderr)
        sys.exit(66)
    normalized_component = re.sub(r"[^a-z0-9]", "", component.lower())
    if normalized_component.startswith("lib") and len(normalized_component) > 3:
        normalized_component = normalized_component[3:]
    components.setdefault(normalized_component, []).append(relative_path.lower())

if not require_release_coverage:
    sys.exit(0)

configure_flags = []
runtime_libraries = []
for key, target in (
    ("requiredConfigureFlags", configure_flags),
    ("requiredRuntimeLibraries", runtime_libraries),
):
    values = manifest.get(key) or []
    if isinstance(values, list):
        target.extend(value for value in values if isinstance(value, str))
for slice_manifest in manifest.get("slices") or []:
    if not isinstance(slice_manifest, dict):
        continue
    for key, target in (
        ("requiredConfigureFlags", configure_flags),
        ("requiredRuntimeLibraries", runtime_libraries),
    ):
        values = slice_manifest.get(key) or []
        if isinstance(values, list):
            target.extend(value for value in values if isinstance(value, str))

if "--enable-nonfree" in configure_flags:
    print(
        "error: FFmpeg --enable-nonfree artifacts are not eligible for the redistributable release gate",
        file=sys.stderr,
    )
    sys.exit(66)

if "ffmpeg" not in components:
    print("error: release artifact is missing FFmpeg license documents", file=sys.stderr)
    sys.exit(66)
ffmpeg_documents = components["ffmpeg"]
is_gpl = "--enable-gpl" in configure_flags
is_version3 = "--enable-version3" in configure_flags
required_token = "gplv3" if is_gpl and is_version3 else (
    "gpl" if is_gpl else ("lgplv3" if is_version3 else "lgpl")
)
if not any(required_token in os.path.basename(path).replace(".", "") for path in ffmpeg_documents):
    print(
        f"error: release artifact is missing the FFmpeg {required_token} license text",
        file=sys.stderr,
    )
    sys.exit(66)

missing_components = []
for runtime_library in runtime_libraries:
    normalized_library = re.sub(r"[^a-z0-9]", "", runtime_library.lower())
    if normalized_library.startswith("lib") and len(normalized_library) > 3:
        normalized_library = normalized_library[3:]
    if normalized_library and normalized_library not in components:
        missing_components.append(runtime_library)
if missing_components:
    missing = ", ".join(dict.fromkeys(missing_components))
    print(f"error: release artifact is missing license documents for: {missing}", file=sys.stderr)
    sys.exit(66)
PY
}

verify_artifact_distribution_support_files() {
  local artifact_root="$1"
  local manifest_path="$2"
  local require_review_packet="${3:-0}"
  python3 - "$artifact_root" "$manifest_path" "$require_review_packet" <<'PY'
import json
import os
import sys

artifact_root = os.path.realpath(sys.argv[1])
manifest_path = sys.argv[2]
require_review_packet = sys.argv[3] == "1"
with open(manifest_path, "r", encoding="utf-8") as handle:
    manifest = json.load(handle)

entries = manifest.get("distributionSupportFiles")
if entries is None:
    entries = []
if not isinstance(entries, list):
    print("error: artifact manifest distributionSupportFiles must be an array", file=sys.stderr)
    sys.exit(66)

allowed_kinds = {
    "attribution",
    "sourceOffer",
    "relinkInstructions",
    "relinkMaterialsManifest",
}
present_kinds = set()
for entry in entries:
    if not isinstance(entry, dict):
        print("error: artifact distribution-support entries must be objects", file=sys.stderr)
        sys.exit(66)
    kind = entry.get("kind")
    relative_path = entry.get("relativePath")
    if kind not in allowed_kinds:
        print(f"error: artifact distribution-support entry has an unsupported kind: {kind}", file=sys.stderr)
        sys.exit(66)
    if not isinstance(relative_path, str) or not relative_path.strip():
        print("error: artifact distribution-support entry is missing a relativePath", file=sys.stderr)
        sys.exit(66)
    if os.path.isabs(relative_path):
        print(f"error: artifact distribution-support path must be relative: {relative_path}", file=sys.stderr)
        sys.exit(66)
    resolved_path = os.path.realpath(os.path.join(artifact_root, relative_path))
    try:
        common_root = os.path.commonpath([artifact_root, resolved_path])
    except ValueError:
        common_root = ""
    if common_root != artifact_root:
        print(f"error: artifact distribution-support path escapes the artifact root: {relative_path}", file=sys.stderr)
        sys.exit(66)
    if not os.path.isfile(resolved_path):
        print(f"error: declared artifact distribution-support file is missing: {relative_path}", file=sys.stderr)
        sys.exit(66)
    if os.path.getsize(resolved_path) <= 0:
        print(f"error: declared artifact distribution-support file is empty: {relative_path}", file=sys.stderr)
        sys.exit(66)
    present_kinds.add(kind)

if not require_review_packet:
    sys.exit(0)

link_mode = manifest.get("swiftpmLinkMode")
if link_mode not in {"search", "static", "framework"}:
    print("error: release artifact must declare swiftpmLinkMode as search, static, or framework", file=sys.stderr)
    sys.exit(66)

missing_kinds = [kind for kind in ("attribution", "sourceOffer") if kind not in present_kinds]
if missing_kinds:
    print(
        "error: release artifact distribution review packet is missing: " + ", ".join(missing_kinds),
        file=sys.stderr,
    )
    sys.exit(66)
if link_mode == "static" and not present_kinds.intersection({"relinkInstructions", "relinkMaterialsManifest"}):
    print(
        "error: static release artifact distribution review packet requires relinkInstructions or relinkMaterialsManifest",
        file=sys.stderr,
    )
    sys.exit(66)
if link_mode == "framework" and "relinkInstructions" not in present_kinds:
    print(
        "error: framework release artifact distribution review packet requires relinkInstructions "
        "that say how to rebuild and replace the runtime framework",
        file=sys.stderr,
    )
    sys.exit(66)
PY
}

verify_artifact_root() {
  local artifact_root="${1:-}"
  if [[ -z "$artifact_root" ]]; then
    echo "error: --verify-artifact-root requires an artifact root" >&2
    exit 64
  fi
  shift || true
  local requested_slices=("$@")

  artifact_root="$(artifact_root_absolute_without_trailing_slash "$artifact_root")"
  local manifest_path
  manifest_path="$(artifact_manifest_path_for_root "$artifact_root")"
  verify_artifact_distribution_licenses "$artifact_root" "$manifest_path" 0
  verify_artifact_distribution_support_files "$artifact_root" "$manifest_path" 0
  adopt_artifact_manifest_configuration "$artifact_root"

  local slice_rows
  if ! slice_rows="$(artifact_manifest_slice_rows "$manifest_path")"; then
    exit 66
  fi
  if [[ -z "$slice_rows" ]]; then
    echo "error: artifact manifest has no slices" >&2
    exit 66
  fi

  local slice_name expected_platform ffmpeg_relative_prefix dependency_relative_prefix
  local manifest_ffmpeg_prefix manifest_dependency_prefix
  local verified_slices=" "
  while IFS=$'\t' read -r \
    slice_name \
    expected_platform \
    ffmpeg_relative_prefix \
    dependency_relative_prefix \
    manifest_ffmpeg_prefix \
    manifest_dependency_prefix; do
    if [[ -z "$slice_name" ]]; then
      continue
    fi
    if [[ ${#requested_slices[@]} -gt 0 ]]; then
      local requested_slice matched_requested_slice=0
      for requested_slice in "${requested_slices[@]}"; do
        if [[ "$slice_name" == "$requested_slice" ]]; then
          matched_requested_slice=1
          break
        fi
      done
      if [[ "$matched_requested_slice" == "0" ]]; then
        continue
      fi
    fi

    local ffmpeg_prefix=""
    if [[ -n "$ffmpeg_relative_prefix" ]]; then
      ffmpeg_prefix="$(artifact_path_from_relative "$artifact_root" "$ffmpeg_relative_prefix")"
    elif [[ -d "${artifact_root}/install/${slice_name}" ]]; then
      ffmpeg_prefix="${artifact_root}/install/${slice_name}"
    elif [[ -n "$manifest_ffmpeg_prefix" ]]; then
      ffmpeg_prefix="$manifest_ffmpeg_prefix"
    else
      ffmpeg_prefix="${artifact_root}/install/${slice_name}"
    fi

    local dependency_prefix=""
    if [[ -n "$dependency_relative_prefix" ]]; then
      dependency_prefix="$(artifact_path_from_relative "$artifact_root" "$dependency_relative_prefix")"
    elif [[ -d "${artifact_root}/dependencies/${slice_name}" ]]; then
      dependency_prefix="${artifact_root}/dependencies/${slice_name}"
    elif [[ -n "$manifest_dependency_prefix" ]]; then
      dependency_prefix="$manifest_dependency_prefix"
    fi

    echo "# Verifying artifact slice ${slice_name}"
    verify_install "$ffmpeg_prefix" "$expected_platform" "$dependency_prefix"
    verify_artifact_xcconfig_settings "$artifact_root" "$slice_name" "$ffmpeg_prefix" "$dependency_prefix"
    if [[ "$(swiftpm_link_mode)" == "framework" ]]; then
      verify_artifact_runtime_framework "$artifact_root" "$manifest_path" "$slice_name"
    fi
    verified_slices="${verified_slices}${slice_name} "
  done <<< "$slice_rows"

  if [[ ${#requested_slices[@]} -gt 0 ]]; then
    local requested_slice
    for requested_slice in "${requested_slices[@]}"; do
      if [[ "$verified_slices" != *" ${requested_slice} "* ]]; then
        echo "error: requested artifact slice is not declared in manifest: ${requested_slice}" >&2
        exit 66
      fi
    done
  fi

  echo "Verified FFmpeg Apple artifact root: ${artifact_root}"
}

verify_artifact_runtime_framework() {
  local artifact_root="$1"
  local manifest_path="$2"
  local slice_name="$3"
  local framework_fields
  if ! framework_fields="$(python3 - "$manifest_path" "$slice_name" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    manifest = json.load(handle)
for slice_manifest in manifest.get("slices") or []:
    if isinstance(slice_manifest, dict) and slice_manifest.get("name") == sys.argv[2]:
        values = [slice_manifest.get(key) for key in (
            "runtimeFrameworkRelativePath",
            "runtimeFrameworkInstallName",
            "runtimeFrameworkBinarySHA256",
            "runtimeFrameworkUUID",
        )]
        if not all(isinstance(value, str) and value for value in values):
            print("error: framework artifact slice must declare runtimeFrameworkRelativePath, "
                  "runtimeFrameworkInstallName, runtimeFrameworkBinarySHA256, and runtimeFrameworkUUID",
                  file=sys.stderr)
            sys.exit(66)
        print("\t".join(values))
        sys.exit(0)
print("error: artifact manifest does not declare slice " + sys.argv[2], file=sys.stderr)
sys.exit(66)
PY
  )"; then
    exit 66
  fi
  local relative_path install_name expected_sha expected_uuid
  IFS=$'\t' read -r relative_path install_name expected_sha expected_uuid <<< "$framework_fields"
  case "$relative_path" in
    /*|..|../*|*/../*|*/..)
      echo "error: runtime framework path must stay inside the artifact root: ${relative_path}" >&2
      exit 66
      ;;
  esac
  if [[ "$install_name" != "$(runtime_framework_install_name)" ]]; then
    echo "error: runtime framework install name must be $(runtime_framework_install_name): ${install_name}" >&2
    exit 66
  fi
  local framework="${artifact_root}/${relative_path}"
  "$(runtime_framework_packager)" --verify "$framework"
  local binary="${framework}/Versions/A/${runtime_framework_name}"
  local actual_sha actual_uuid
  actual_sha="$(runtime_framework_binary_sha256 "$binary")"
  actual_uuid="$(runtime_framework_binary_uuid "$binary")"
  if [[ "$actual_sha" != "$expected_sha" ]]; then
    echo "error: runtime framework checksum mismatch: expected ${expected_sha}, found ${actual_sha}" >&2
    exit 66
  fi
  if [[ "$actual_uuid" != "$expected_uuid" ]]; then
    echo "error: runtime framework UUID mismatch: expected ${expected_uuid}, found ${actual_uuid}" >&2
    exit 66
  fi
}

verify_release_artifact_root() {
  local artifact_root="${1:-}"
  if [[ -z "$artifact_root" ]]; then
    echo "error: --verify-release-artifact-root requires an artifact root" >&2
    exit 64
  fi
  artifact_root="$(artifact_root_absolute_without_trailing_slash "$artifact_root")"
  verify_artifact_root "$artifact_root" "${@:2}"
  local manifest_path
  manifest_path="$(artifact_manifest_path_for_root "$artifact_root")"
  verify_artifact_distribution_licenses "$artifact_root" "$manifest_path" 1
  verify_artifact_distribution_support_files "$artifact_root" "$manifest_path" 1
  echo "Verified FFmpeg Apple release artifact review packet files (legal review still required): ${artifact_root}"
}

xcrun_sdk_for_apple_sdk() {
  case "$1" in
    maccatalyst)
      printf 'macosx'
      ;;
    *)
      printf '%s' "$1"
      ;;
  esac
}

sdk_path() {
  local sdk="$1"
  local xcrun_sdk
  xcrun_sdk="$(xcrun_sdk_for_apple_sdk "$sdk")"
  xcrun --sdk "$xcrun_sdk" --show-sdk-path
}

clang_path() {
  local sdk="$1"
  local xcrun_sdk
  xcrun_sdk="$(xcrun_sdk_for_apple_sdk "$sdk")"
  xcrun --sdk "$xcrun_sdk" -f clang
}

ar_path() {
  local sdk="$1"
  local xcrun_sdk
  xcrun_sdk="$(xcrun_sdk_for_apple_sdk "$sdk")"
  xcrun --sdk "$xcrun_sdk" -f ar
}

resolve_pkg_config() {
  if [[ -n "${NSURATOR_PLAYER_CORE_PKG_CONFIG:-}" ]]; then
    printf '%s' "${NSURATOR_PLAYER_CORE_PKG_CONFIG}"
    return 0
  fi

  local discovered=""
  if discovered="$(command -v pkg-config 2>/dev/null)"; then
    printf '%s' "$discovered"
    return 0
  fi
  if discovered="$(command -v pkgconf 2>/dev/null)"; then
    printf '%s' "$discovered"
    return 0
  fi

  local candidate
  for candidate in /opt/homebrew/bin/pkg-config /usr/local/bin/pkg-config; do
    if [[ -x "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  printf 'pkg-config'
}

path_contains_whitespace() {
  [[ "$1" == *[[:space:]]* ]]
}

path_for_directory() {
  local path="$1"
  local directory="$2"
  if [[ -z "$path" || "$path" == /* ]]; then
    printf '%s' "$path"
    return 0
  fi

  python3 - "$directory" "$path" <<'PY'
import os
import sys

base = os.path.abspath(sys.argv[1])
target = os.path.abspath(sys.argv[2])
print(os.path.relpath(target, base))
PY
}

validate_ffmpeg_build_paths_without_whitespace() {
  local invalid_paths=()
  while [[ "$#" -gt 0 ]]; do
    local name="$1"
    local path="$2"
    shift 2
    if [[ -n "$path" ]] && path_contains_whitespace "$path"; then
      invalid_paths+=("${name}=${path}")
    fi
  done

  if [[ "${#invalid_paths[@]}" -eq 0 ]]; then
    return 0
  fi

  echo "error: FFmpeg Apple build paths cannot contain whitespace." >&2
  echo "FFmpeg configure splits source and compiler flag paths during out-of-tree builds." >&2
  echo "Use no-space symlinks or set FFMPEG_SOURCE_DIR, NSURATOR_PLAYER_CORE_FFMPEG_BUILD_DIR," >&2
  echo "NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR, and NSURATOR_PLAYER_CORE_DEP_PREFIX under a path like /tmp/npc-ffmpeg." >&2
  local invalid_path
  for invalid_path in "${invalid_paths[@]}"; do
    echo "  ${invalid_path}" >&2
  done
  exit 64
}

validate_libdvd_install_path_without_whitespace() {
  local install_root="$1"
  if ! path_contains_whitespace "$install_root"; then
    return 0
  fi

  echo "error: the libdvdread/libdvdnav Apple install path cannot contain whitespace." >&2
  echo "Their pkg-config files cannot represent a dependency prefix containing spaces safely." >&2
  echo "Run --prepare-no-space-build-env or set NSURATOR_PLAYER_CORE_DEP_PREFIX or" >&2
  echo "NSURATOR_PLAYER_CORE_LIBDVD_INSTALL_DIR under a path like /tmp/npc-ffmpeg." >&2
  echo "  installRoot=${install_root}" >&2
  exit 64
}

make_configure_command() {
  local slice_name="$1"
  local sdk="$2"
  local target_triple="$3"
  local source_dir="$4"
  local install_prefix="$5"
  local sysroot="$6"
  local cc="$7"
  local dep_prefix=""
  if [[ -n "${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}" ]]; then
    dep_prefix="$(dependency_prefix_for_slice "$slice_name")"
  fi
  local dep_cflags="${NSURATOR_PLAYER_CORE_DEP_CFLAGS:-}"
  local dep_ldflags="${NSURATOR_PLAYER_CORE_DEP_LDFLAGS:-}"
  local pkg_config
  pkg_config="$(resolve_pkg_config)"
  local profile
  profile="$(ffmpeg_link_profile)"

  local extra_cflags="-target ${target_triple} -isysroot ${sysroot} -fembed-bitcode -fPIC"
  local extra_ldflags="-target ${target_triple} -isysroot ${sysroot}"
  local pkg_config_libdir=""

  if [[ -n "$dep_prefix" ]]; then
    extra_cflags="${extra_cflags} -I${dep_prefix}/include"
    extra_ldflags="${extra_ldflags} -L${dep_prefix}/lib"
    pkg_config_libdir="${dep_prefix}/lib/pkgconfig"
  fi
  if [[ -n "$dep_cflags" ]]; then
    extra_cflags="${extra_cflags} ${dep_cflags}"
  fi
  if [[ -n "$dep_ldflags" ]]; then
    extra_ldflags="${extra_ldflags} ${dep_ldflags}"
  fi

  local command=(
    "${source_dir}/configure"
    "--prefix=${install_prefix}"
    "--enable-cross-compile"
    "--target-os=darwin"
    "--arch=arm64"
    "--cc=${cc}"
    "--sysroot=${sysroot}"
    "--enable-static"
    "--disable-shared"
    "--enable-pic"
    "--disable-programs"
    "--disable-doc"
    "--disable-debug"
    "--disable-avdevice"
    "--disable-devices"
    "--enable-avcodec"
    "--enable-avformat"
    "--enable-avutil"
    "--enable-swresample"
    "--enable-swscale"
    "--enable-libbluray"
    "--enable-videotoolbox"
    "--pkg-config=${pkg_config}"
    "--extra-cflags=${extra_cflags}"
    "--extra-ldflags=${extra_ldflags}"
  )

  if [[ "$profile" == "full" ]]; then
    command+=(
      "--enable-libdav1d"
      "--enable-libdvdnav"
      "--enable-libdvdread"
      "${modern_video_configure_flags[@]}"
    )
  fi

  if network_protocols_enabled; then
    command+=("${network_protocol_configure_flags[@]}")
  fi
  local extra_ffmpeg_configure_flags="${NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS:-}"
  if [[ -n "$extra_ffmpeg_configure_flags" ]]; then
    local extra_configure_flags=()
    read -r -a extra_configure_flags <<< "$extra_ffmpeg_configure_flags"
    command+=("${extra_configure_flags[@]}")
  fi

  echo "# ${slice_name}"
  if [[ -n "$pkg_config_libdir" ]]; then
    printf 'PKG_CONFIG_LIBDIR='
    quote "$pkg_config_libdir"
    printf ' PKG_CONFIG_PATH= '
  fi
  join_quoted "${command[@]}"
  echo
}

build_slice() {
  local slice_name="$1"
  local sdk="$2"
  local target_triple="$3"
  local source_dir="$4"
  local build_root="$5"
  local install_root="$6"
  local dry_run="$7"
  local sysroot
  local cc
  local build_dir
  local install_prefix

  sysroot="$(sdk_path "$sdk")"
  cc="$(clang_path "$sdk")"
  build_dir="${build_root}/${slice_name}"
  install_prefix="${install_root}/${slice_name}"

  if [[ "$dry_run" == "1" ]]; then
    make_configure_command "$slice_name" "$sdk" "$target_triple" "$source_dir" "$install_prefix" "$sysroot" "$cc"
    echo "# ${slice_name} build"
    echo "make -C $(quote "$build_dir") -j\$(sysctl -n hw.ncpu)"
    echo "make -C $(quote "$build_dir") install"
    return 0
  fi

  mkdir -p "$build_dir"
  (
    local build_source_dir
    local build_install_prefix
    build_source_dir="$(path_for_directory "$source_dir" "$build_dir")"
    build_install_prefix="$(path_for_directory "$install_prefix" "$build_dir")"
    if [[ -n "${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}" ]]; then
      NSURATOR_PLAYER_CORE_DEP_PREFIX="$(path_for_directory "$NSURATOR_PLAYER_CORE_DEP_PREFIX" "$build_dir")"
      export NSURATOR_PLAYER_CORE_DEP_PREFIX
    fi
    cd "$build_dir"
    local configure_line
    configure_line="$(make_configure_command "$slice_name" "$sdk" "$target_triple" "$build_source_dir" "$build_install_prefix" "$sysroot" "$cc" | tail -n +2)"
    eval "$configure_line"
    make -j"$(sysctl -n hw.ncpu)"
    make install
  )
}

write_dav1d_cross_file() {
  local cross_file="$1"
  local cc="$2"
  local ar="$3"
  local target_triple="$4"
  local sysroot="$5"
  local host_system="${6:-darwin}"

  mkdir -p "$(dirname "$cross_file")"
  cat > "$cross_file" <<CROSS
[binaries]
c = ['${cc}', '-target', '${target_triple}', '-isysroot', '${sysroot}', '-fembed-bitcode', '-fPIC']
ar = '${ar}'

[built-in options]
c_args = ['-target', '${target_triple}', '-isysroot', '${sysroot}', '-fembed-bitcode', '-fPIC']
c_link_args = ['-target', '${target_triple}', '-isysroot', '${sysroot}']

[properties]
needs_exe_wrapper = true

[host_machine]
system = '${host_system}'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'
CROSS
}

libbluray_meson_host_system_for_sdk() {
  case "$1" in
    iphoneos|iphonesimulator|appletvos|appletvsimulator)
      printf 'ios'
      ;;
    *)
      printf 'darwin'
      ;;
  esac
}

make_dav1d_setup_command() {
  local slice_name="$1"
  local source_dir="$2"
  local build_dir="$3"
  local install_prefix="$4"
  local cross_file="$5"
  local meson="${NSURATOR_PLAYER_CORE_MESON:-meson}"

  local command=(
    "$meson"
    "setup"
    "$build_dir"
    "$source_dir"
    "--cross-file"
    "$cross_file"
    "--prefix=${install_prefix}"
    "--libdir=lib"
    "--buildtype=release"
    "-Ddefault_library=static"
    "-Denable_tools=false"
    "-Denable_tests=false"
    "-Denable_examples=false"
    "-Denable_docs=false"
    "--wrap-mode=nodownload"
  )

  echo "# dav1d ${slice_name}"
  join_quoted "${command[@]}"
  echo
}

build_dav1d_slice() {
  local slice_name="$1"
  local sdk="$2"
  local target_triple="$3"
  local source_dir="$4"
  local build_root="$5"
  local install_root="$6"
  local dry_run="$7"
  local sysroot
  local cc
  local ar
  local build_dir
  local install_prefix
  local cross_file
  local meson="${NSURATOR_PLAYER_CORE_MESON:-meson}"

  sysroot="$(sdk_path "$sdk")"
  cc="$(clang_path "$sdk")"
  ar="$(ar_path "$sdk")"
  build_dir="${build_root}/${slice_name}"
  install_prefix="${install_root}/${slice_name}"
  cross_file="${build_dir}/dav1d-${slice_name}.cross"

  if [[ "$dry_run" == "1" ]]; then
    echo "# dav1d ${slice_name} cross-file"
    echo "target=${target_triple}"
    echo "sysroot=${sysroot}"
    make_dav1d_setup_command "$slice_name" "$source_dir" "$build_dir" "$install_prefix" "$cross_file"
    echo "$meson compile -C $(quote "$build_dir")"
    echo "$meson install -C $(quote "$build_dir")"
    return 0
  fi

  if ! command -v "$meson" >/dev/null 2>&1; then
    echo "error: meson executable not found: ${meson}" >&2
    exit 66
  fi

  write_dav1d_cross_file "$cross_file" "$cc" "$ar" "$target_triple" "$sysroot"
  if [[ -f "${build_dir}/build.ninja" ]]; then
    "$meson" setup --reconfigure "$build_dir" "$source_dir" \
      --cross-file "$cross_file" \
      "--prefix=${install_prefix}" \
      "--libdir=lib" \
      "--buildtype=release" \
      "-Ddefault_library=static" \
      "-Denable_tools=false" \
      "-Denable_tests=false" \
      "-Denable_examples=false" \
      "-Denable_docs=false" \
      "--wrap-mode=nodownload"
  else
    "$meson" setup "$build_dir" "$source_dir" \
      --cross-file "$cross_file" \
      "--prefix=${install_prefix}" \
      "--libdir=lib" \
      "--buildtype=release" \
      "-Ddefault_library=static" \
      "-Denable_tools=false" \
      "-Denable_tests=false" \
      "-Denable_examples=false" \
      "-Denable_docs=false" \
      "--wrap-mode=nodownload"
  fi
  "$meson" compile -C "$build_dir"
  "$meson" install -C "$build_dir"
}

build_dav1d() {
  local dry_run="$1"
  local source_dir="${DAV1D_SOURCE_DIR:-}"
  if [[ -z "$source_dir" ]]; then
    echo "error: DAV1D_SOURCE_DIR is required for --build-dav1d" >&2
    exit 64
  fi
  if [[ "$dry_run" != "1" && ! -f "${source_dir}/meson.build" ]]; then
    echo "error: DAV1D_SOURCE_DIR does not contain meson.build: ${source_dir}" >&2
    exit 66
  fi

  local package_root
  package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local build_root="${NSURATOR_PLAYER_CORE_DAV1D_BUILD_DIR:-${package_root}/.build/dav1d-visionos}"
  local install_root="${NSURATOR_PLAYER_CORE_DEP_PREFIX:-${NSURATOR_PLAYER_CORE_DAV1D_INSTALL_DIR:-${build_root}/install}}"
  source_dir="$(artifact_root_absolute_without_trailing_slash "$source_dir")"
  build_root="$(artifact_root_absolute_without_trailing_slash "$build_root")"
  install_root="$(artifact_root_absolute_without_trailing_slash "$install_root")"

  local slice_definition
  for slice_definition in $(selected_apple_build_slices); do
    local slice_name sdk target_triple expected_platform xcconfig_sdk_condition
    IFS='|' read -r slice_name sdk target_triple expected_platform xcconfig_sdk_condition <<< "$slice_definition"
    build_dav1d_slice "$slice_name" "$sdk" "$target_triple" "$source_dir" "$build_root" "$install_root" "$dry_run"
  done

  if [[ "$dry_run" != "1" ]]; then
    echo "Built dav1d Apple slices under: ${install_root}"
  fi
}

make_libbluray_setup_command() {
  local slice_name="$1"
  local source_dir="$2"
  local build_dir="$3"
  local install_prefix="$4"
  local cross_file="$5"
  local meson="${NSURATOR_PLAYER_CORE_MESON:-meson}"

  local command=(
    "$meson"
    "setup"
    "$build_dir"
    "$source_dir"
    "--cross-file"
    "$cross_file"
    "--prefix=${install_prefix}"
    "--libdir=lib"
    "--buildtype=release"
    "-Ddefault_library=static"
    "-Denable_tools=false"
    "-Denable_devtools=false"
    "-Denable_examples=false"
    "-Denable_docs=false"
    "-Dbdj_jar=disabled"
    "-Dfreetype=disabled"
    "-Dfontconfig=disabled"
    "-Dlibxml2=disabled"
    "-Dembed_udfread=true"
    "--force-fallback-for=libudfread"
    "--wrap-mode=nodownload"
  )

  echo "# libbluray ${slice_name}"
  join_quoted "${command[@]}"
  echo
}

build_libbluray_slice() {
  local slice_name="$1"
  local sdk="$2"
  local target_triple="$3"
  local source_dir="$4"
  local build_root="$5"
  local install_root="$6"
  local dry_run="$7"
  local sysroot
  local cc
  local ar
  local build_dir
  local install_prefix
  local cross_file
  local meson="${NSURATOR_PLAYER_CORE_MESON:-meson}"
  local host_system

  sysroot="$(sdk_path "$sdk")"
  cc="$(clang_path "$sdk")"
  ar="$(ar_path "$sdk")"
  build_dir="${build_root}/${slice_name}"
  install_prefix="${install_root}/${slice_name}"
  cross_file="${build_dir}/libbluray-${slice_name}.cross"
  host_system="$(libbluray_meson_host_system_for_sdk "$sdk")"

  if [[ "$dry_run" == "1" ]]; then
    echo "# libbluray ${slice_name} cross-file"
    echo "target=${target_triple}"
    echo "sysroot=${sysroot}"
    echo "meson-system=${host_system}"
    make_libbluray_setup_command "$slice_name" "$source_dir" "$build_dir" "$install_prefix" "$cross_file"
    echo "$meson compile -C $(quote "$build_dir")"
    echo "$meson install -C $(quote "$build_dir")"
    return 0
  fi

  if ! command -v "$meson" >/dev/null 2>&1; then
    echo "error: meson executable not found: ${meson}" >&2
    exit 66
  fi

  write_dav1d_cross_file "$cross_file" "$cc" "$ar" "$target_triple" "$sysroot" "$host_system"
  if [[ -f "${build_dir}/build.ninja" ]]; then
    "$meson" setup --reconfigure "$build_dir" "$source_dir" \
      --cross-file "$cross_file" \
      "--prefix=${install_prefix}" \
      "--libdir=lib" \
      "--buildtype=release" \
      "-Ddefault_library=static" \
      "-Denable_tools=false" \
      "-Denable_devtools=false" \
      "-Denable_examples=false" \
      "-Denable_docs=false" \
      "-Dbdj_jar=disabled" \
      "-Dfreetype=disabled" \
      "-Dfontconfig=disabled" \
      "-Dlibxml2=disabled" \
      "-Dembed_udfread=true" \
      "--force-fallback-for=libudfread" \
      "--wrap-mode=nodownload"
  else
    "$meson" setup "$build_dir" "$source_dir" \
      --cross-file "$cross_file" \
      "--prefix=${install_prefix}" \
      "--libdir=lib" \
      "--buildtype=release" \
      "-Ddefault_library=static" \
      "-Denable_tools=false" \
      "-Denable_devtools=false" \
      "-Denable_examples=false" \
      "-Denable_docs=false" \
      "-Dbdj_jar=disabled" \
      "-Dfreetype=disabled" \
      "-Dfontconfig=disabled" \
      "-Dlibxml2=disabled" \
      "-Dembed_udfread=true" \
      "--force-fallback-for=libudfread" \
      "--wrap-mode=nodownload"
  fi
  "$meson" compile -C "$build_dir"
  "$meson" install -C "$build_dir"
}

apply_libbluray_source_patches() {
  local source_dir="$1"
  local mobile_java_patch
  mobile_java_patch="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patches/libbluray-apple-mobile-java-home.patch"
  if [[ -f "${source_dir}/src/libbluray/bdj/bdj.c" ]] &&
      ! grep -q NPC_LIBBLURAY_NO_MOBILE_JAVA_HOME "${source_dir}/src/libbluray/bdj/bdj.c"; then
    patch --batch --forward -d "$source_dir" -p1 < "$mobile_java_patch"
  fi
  local package_root
  local angle_change_patch_file
  local menu_button_patch_file
  local decryption_patch_file
  local clpi_source_file
  local bluray_header_file
  local bluray_source_file
  local overlay_header_file
  local graphics_controller_header_file
  local graphics_controller_source_file
  local aacs_source_file
  local bdplus_source_file
  package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  angle_change_patch_file="${package_root}/scripts/patches/libbluray-next-coarse-angle-change-point.patch"
  menu_button_patch_file="${package_root}/scripts/patches/libbluray-hdmv-menu-button-snapshot.patch"
  decryption_patch_file="${package_root}/scripts/patches/libbluray-disable-decryption-library-loading.patch"
  clpi_source_file="${source_dir}/src/libbluray/bdnav/clpi_parse.c"
  bluray_header_file="${source_dir}/src/libbluray/bluray.h"
  bluray_source_file="${source_dir}/src/libbluray/bluray.c"
  overlay_header_file="${source_dir}/src/libbluray/decoders/overlay.h"
  graphics_controller_header_file="${source_dir}/src/libbluray/decoders/graphics_controller.h"
  graphics_controller_source_file="${source_dir}/src/libbluray/decoders/graphics_controller.c"
  aacs_source_file="${source_dir}/src/libbluray/disc/aacs.c"
  bdplus_source_file="${source_dir}/src/libbluray/disc/bdplus.c"

  if ! command -v patch >/dev/null 2>&1; then
    echo "error: patch executable is required for the libbluray source patch" >&2
    exit 66
  fi

  if ! grep -q "NPC_LIBBLURAY_REFRESH_NEXT_COARSE_RANGE" "$clpi_source_file"; then
    if ! patch --batch --forward -d "$source_dir" -p1 < "$angle_change_patch_file"; then
      echo "error: libbluray source is incompatible with the seamless-angle patch" >&2
      exit 66
    fi
  fi
  if ! grep -q "NPC_LIBBLURAY_REFRESH_NEXT_COARSE_RANGE" "$clpi_source_file"; then
    echo "error: libbluray seamless-angle patch did not install its verification marker" >&2
    exit 66
  fi

  local menu_button_patch_markers=0
  if grep -q "NPC_LIBBLURAY_HDMV_MENU_BUTTON_SNAPSHOT" "$bluray_header_file"; then
    menu_button_patch_markers=$((menu_button_patch_markers + 1))
  fi
  if grep -q "NPC_LIBBLURAY_HDMV_MENU_BUTTON_SNAPSHOT" "$bluray_source_file"; then
    menu_button_patch_markers=$((menu_button_patch_markers + 1))
  fi
  if grep -q "NPC_LIBBLURAY_HDMV_MENU_BUTTON_SNAPSHOT" "$overlay_header_file"; then
    menu_button_patch_markers=$((menu_button_patch_markers + 1))
  fi
  if grep -q "GC_CTRL_BUTTON_SELECT" "$graphics_controller_header_file"; then
    menu_button_patch_markers=$((menu_button_patch_markers + 1))
  fi
  if grep -q "NPC_LIBBLURAY_HDMV_MENU_BUTTON_SNAPSHOT" "$graphics_controller_source_file"; then
    menu_button_patch_markers=$((menu_button_patch_markers + 1))
  fi
  if (( menu_button_patch_markers != 0 && menu_button_patch_markers != 5 )); then
    echo "error: libbluray HDMV menu-button patch is only partially installed" >&2
    exit 66
  fi
  if (( menu_button_patch_markers == 0 )); then
    if ! patch --batch --forward -d "$source_dir" -p1 < "$menu_button_patch_file"; then
      echo "error: libbluray source is incompatible with the HDMV menu-button patch" >&2
      exit 66
    fi
  fi
  if
    ! grep -q "NPC_LIBBLURAY_HDMV_MENU_BUTTON_SNAPSHOT" "$bluray_header_file" ||
    ! grep -q "NPC_LIBBLURAY_HDMV_MENU_BUTTON_SNAPSHOT" "$bluray_source_file" ||
    ! grep -q "NPC_LIBBLURAY_HDMV_MENU_BUTTON_SNAPSHOT" "$overlay_header_file" ||
    ! grep -q "GC_CTRL_BUTTON_SELECT" "$graphics_controller_header_file" ||
    ! grep -q "NPC_LIBBLURAY_HDMV_MENU_BUTTON_SNAPSHOT" "$graphics_controller_source_file"
  then
    echo "error: libbluray HDMV menu-button patch did not install all verification markers" >&2
    exit 66
  fi

  local aacs_loading_disabled=0
  local bdplus_loading_disabled=0
  if grep -q "NPC_LIBBLURAY_DISABLE_AACS_BDPLUS_DLOPEN" "$aacs_source_file"; then
    aacs_loading_disabled=1
  fi
  if grep -q "NPC_LIBBLURAY_DISABLE_AACS_BDPLUS_DLOPEN" "$bdplus_source_file"; then
    bdplus_loading_disabled=1
  fi
  if [[ "$aacs_loading_disabled" != "$bdplus_loading_disabled" ]]; then
    echo "error: libbluray decryption-library patch is only partially installed" >&2
    exit 66
  fi
  if [[ "$aacs_loading_disabled" == "0" ]]; then
    if ! patch --batch --forward -d "$source_dir" -p1 < "$decryption_patch_file"; then
      echo "error: libbluray source is incompatible with the fail-closed decryption-library patch" >&2
      exit 66
    fi
  fi
  if
    ! grep -q "NPC_LIBBLURAY_DISABLE_AACS_BDPLUS_DLOPEN" "$aacs_source_file" ||
    ! grep -q "NPC_LIBBLURAY_DISABLE_AACS_BDPLUS_DLOPEN" "$bdplus_source_file"
  then
    echo "error: libbluray fail-closed decryption-library patch did not install both verification markers" >&2
    exit 66
  fi
}

build_libbluray() {
  local dry_run="$1"
  local source_dir="${LIBBLURAY_SOURCE_DIR:-}"
  if [[ -z "$source_dir" ]]; then
    echo "error: LIBBLURAY_SOURCE_DIR is required for --build-libbluray" >&2
    exit 64
  fi
  if [[ "$dry_run" != "1" && ! -f "${source_dir}/meson.build" ]]; then
    echo "error: LIBBLURAY_SOURCE_DIR does not contain meson.build: ${source_dir}" >&2
    exit 66
  fi

  local package_root
  package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local build_root="${NSURATOR_PLAYER_CORE_LIBBLURAY_BUILD_DIR:-${package_root}/.build/libbluray-visionos}"
  local install_root="${NSURATOR_PLAYER_CORE_DEP_PREFIX:-${NSURATOR_PLAYER_CORE_LIBBLURAY_INSTALL_DIR:-${build_root}/install}}"
  source_dir="$(artifact_root_absolute_without_trailing_slash "$source_dir")"
  build_root="$(artifact_root_absolute_without_trailing_slash "$build_root")"
  install_root="$(artifact_root_absolute_without_trailing_slash "$install_root")"

  if [[ "$dry_run" != "1" ]]; then
    apply_libbluray_source_patches "$source_dir"
  fi

  local slice_definition
  for slice_definition in $(selected_apple_build_slices); do
    local slice_name sdk target_triple expected_platform xcconfig_sdk_condition
    IFS='|' read -r slice_name sdk target_triple expected_platform xcconfig_sdk_condition <<< "$slice_definition"
    build_libbluray_slice "$slice_name" "$sdk" "$target_triple" "$source_dir" "$build_root" "$install_root" "$dry_run"
  done

  if [[ "$dry_run" != "1" ]]; then
    echo "Built libbluray Apple slices under: ${install_root}"
  fi
}

apply_libdvdread_source_patches() {
  local source_dir="$1"
  local package_root
  local css_patch_file
  local meson_patch_file
  local filesystem_symbol_patch_file
  package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  css_patch_file="${package_root}/scripts/patches/libdvdread-disable-dvdcss-dlopen.patch"
  meson_patch_file="${package_root}/scripts/patches/libdvdread-meson-source-git.patch"
  filesystem_symbol_patch_file="${package_root}/scripts/patches/libdvdread-prefix-filesystem-symbols.patch"

  if ! command -v patch >/dev/null 2>&1; then
    echo "error: patch executable is required for the libdvdread source patches" >&2
    exit 66
  fi

  if ! grep -q "NPC_LIBDVDREAD_DISABLE_DVDCSS_DLOPEN" "${source_dir}/src/dvd_input.c"; then
    if ! patch --batch --forward -d "$source_dir" -p1 < "$css_patch_file"; then
      echo "error: libdvdread source is incompatible with the required fail-closed patch" >&2
      exit 66
    fi
  fi
  if ! grep -q "NPC_LIBDVDREAD_DISABLE_DVDCSS_DLOPEN" "${source_dir}/src/dvd_input.c"; then
    echo "error: libdvdread fail-closed patch did not install its verification marker" >&2
    exit 66
  fi

  if ! grep -q "'git', '-C', dvdread_src_root, 'log'" "${source_dir}/meson.build"; then
    if ! patch --batch --forward -d "$source_dir" -p1 < "$meson_patch_file"; then
      echo "error: libdvdread source is incompatible with the checkout-build patch" >&2
      exit 66
    fi
  fi
  if ! grep -q "'git', '-C', dvdread_src_root, 'log'" "${source_dir}/meson.build"; then
    echo "error: libdvdread checkout-build patch did not install its verification marker" >&2
    exit 66
  fi

  if ! grep -q "NPC_LIBDVDREAD_PREFIX_FILESYSTEM_SYMBOLS" "${source_dir}/src/file/filesystem.h"; then
    if ! patch --batch --forward -d "$source_dir" -p1 < "$filesystem_symbol_patch_file"; then
      echo "error: libdvdread source is incompatible with the filesystem-symbol isolation patch" >&2
      exit 66
    fi
  fi
  if ! grep -q "NPC_LIBDVDREAD_PREFIX_FILESYSTEM_SYMBOLS" "${source_dir}/src/file/filesystem.h"; then
    echo "error: libdvdread filesystem-symbol patch did not install its verification marker" >&2
    exit 66
  fi
}

write_libdvd_cross_file() {
  local cross_file="$1"
  local cc="$2"
  local ar="$3"
  local pkg_config="$4"
  local target_triple="$5"
  local sysroot="$6"
  local host_system="$7"

  mkdir -p "$(dirname "$cross_file")"
  cat > "$cross_file" <<CROSS
[binaries]
c = ['${cc}', '-target', '${target_triple}', '-isysroot', '${sysroot}', '-fembed-bitcode', '-fPIC']
ar = '${ar}'
pkg-config = '${pkg_config}'

[built-in options]
c_args = ['-target', '${target_triple}', '-isysroot', '${sysroot}', '-fembed-bitcode', '-fPIC']
c_link_args = ['-target', '${target_triple}', '-isysroot', '${sysroot}']

[properties]
needs_exe_wrapper = true

[host_machine]
system = '${host_system}'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'
CROSS
}

libdvd_meson_options() {
  local dependency="$1"
  printf '%s\n' \
    "--libdir=lib" \
    "--buildtype=release" \
    "-Ddefault_library=static" \
    "-Denable_docs=false"
  case "$dependency" in
    libdvdread)
      printf '%s\n' \
        "-Dlibdvdcss=disabled" \
        "-Dc_args=-DNPC_LIBDVDREAD_DISABLE_DVDCSS_DLOPEN=1"
      ;;
    libdvdnav)
      printf '%s\n' "-Denable_examples=false"
      ;;
    *)
      echo "error: unsupported DVD dependency: ${dependency}" >&2
      exit 64
      ;;
  esac
  printf '%s\n' "--wrap-mode=nodownload"
}

make_libdvd_setup_command() {
  local dependency="$1"
  local slice_name="$2"
  local source_dir="$3"
  local build_dir="$4"
  local install_prefix="$5"
  local cross_file="$6"
  local meson="${NSURATOR_PLAYER_CORE_MESON:-meson}"
  local options=()
  while IFS= read -r option; do
    options+=("$option")
  done < <(libdvd_meson_options "$dependency")
  local command=(
    "$meson"
    "setup"
    "$build_dir"
    "$source_dir"
    "--cross-file"
    "$cross_file"
    "--prefix=${install_prefix}"
    "${options[@]}"
  )

  echo "# ${dependency} ${slice_name}"
  if [[ "$dependency" == "libdvdnav" ]]; then
    printf 'PKG_CONFIG_LIBDIR='
    quote "${install_prefix}/lib/pkgconfig"
    printf ' PKG_CONFIG_PATH= '
  fi
  join_quoted "${command[@]}"
  echo
}

build_libdvd_slice() {
  local dependency="$1"
  local slice_name="$2"
  local sdk="$3"
  local target_triple="$4"
  local source_dir="$5"
  local build_root="$6"
  local install_root="$7"
  local dry_run="$8"
  local sysroot
  local cc
  local ar
  local pkg_config="${NSURATOR_PLAYER_CORE_PKG_CONFIG:-pkg-config}"
  local build_dir
  local install_prefix
  local cross_file
  local meson="${NSURATOR_PLAYER_CORE_MESON:-meson}"
  local host_system
  local options=()

  sysroot="$(sdk_path "$sdk")"
  cc="$(clang_path "$sdk")"
  ar="$(ar_path "$sdk")"
  build_dir="${build_root}/${slice_name}"
  install_prefix="${install_root}/${slice_name}"
  cross_file="${build_dir}/${dependency}-${slice_name}.cross"
  host_system="$(libbluray_meson_host_system_for_sdk "$sdk")"
  while IFS= read -r option; do
    options+=("$option")
  done < <(libdvd_meson_options "$dependency")

  if [[ "$dry_run" == "1" ]]; then
    echo "# ${dependency} ${slice_name} cross-file"
    echo "target=${target_triple}"
    echo "sysroot=${sysroot}"
    echo "meson-system=${host_system}"
    make_libdvd_setup_command \
      "$dependency" "$slice_name" "$source_dir" "$build_dir" "$install_prefix" "$cross_file"
    echo "$meson compile -C $(quote "$build_dir")"
    echo "$meson install -C $(quote "$build_dir")"
    return 0
  fi

  if ! command -v "$meson" >/dev/null 2>&1; then
    echo "error: meson executable not found: ${meson}" >&2
    exit 66
  fi
  if ! command -v "$pkg_config" >/dev/null 2>&1; then
    echo "error: pkg-config executable not found: ${pkg_config}" >&2
    exit 66
  fi
  if [[ "$dependency" == "libdvdnav" ]]; then
    if [[ ! -f "${install_prefix}/include/dvdread/dvd_reader.h" ||
          ! -f "${install_prefix}/lib/libdvdread.a" ||
          ! -f "${install_prefix}/lib/pkgconfig/dvdread.pc" ]]; then
      echo "error: ${dependency} ${slice_name} requires libdvdread in ${install_prefix}; build --build-libdvdread first" >&2
      exit 66
    fi
  fi

  write_libdvd_cross_file \
    "$cross_file" "$cc" "$ar" "$pkg_config" "$target_triple" "$sysroot" "$host_system"
  local setup_command=(
    "$meson"
    "setup"
  )
  if [[ -f "${build_dir}/build.ninja" ]]; then
    setup_command+=("--reconfigure")
  fi
  setup_command+=(
    "$build_dir"
    "$source_dir"
    "--cross-file"
    "$cross_file"
    "--prefix=${install_prefix}"
    "${options[@]}"
  )
  if [[ "$dependency" == "libdvdnav" ]]; then
    PKG_CONFIG_LIBDIR="${install_prefix}/lib/pkgconfig" PKG_CONFIG_PATH= \
      "${setup_command[@]}"
  else
    "${setup_command[@]}"
  fi
  "$meson" compile -C "$build_dir"
  "$meson" install -C "$build_dir"
}

build_libdvd_dependency() {
  local dependency="$1"
  local dry_run="$2"
  local source_environment
  local build_environment
  case "$dependency" in
    libdvdread)
      source_environment="LIBDVDREAD_SOURCE_DIR"
      build_environment="NSURATOR_PLAYER_CORE_LIBDVDREAD_BUILD_DIR"
      ;;
    libdvdnav)
      source_environment="LIBDVDNAV_SOURCE_DIR"
      build_environment="NSURATOR_PLAYER_CORE_LIBDVDNAV_BUILD_DIR"
      ;;
    *)
      echo "error: unsupported DVD dependency: ${dependency}" >&2
      exit 64
      ;;
  esac

  local source_dir="${!source_environment:-}"
  if [[ -z "$source_dir" ]]; then
    echo "error: ${source_environment} is required for --build-${dependency}" >&2
    exit 64
  fi
  if [[ "$dry_run" != "1" && ! -f "${source_dir}/meson.build" ]]; then
    echo "error: ${source_environment} does not contain meson.build: ${source_dir}" >&2
    exit 66
  fi

  local package_root
  package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local default_build_root="${package_root}/.build/${dependency}-visionos"
  local build_root="${!build_environment:-$default_build_root}"
  local install_root="${NSURATOR_PLAYER_CORE_DEP_PREFIX:-${NSURATOR_PLAYER_CORE_LIBDVD_INSTALL_DIR:-${package_root}/.build/libdvd-visionos/install}}"
  source_dir="$(artifact_root_absolute_without_trailing_slash "$source_dir")"
  build_root="$(artifact_root_absolute_without_trailing_slash "$build_root")"
  install_root="$(artifact_root_absolute_without_trailing_slash "$install_root")"

  if [[ "$dry_run" != "1" ]]; then
    validate_libdvd_install_path_without_whitespace "$install_root"
    if [[ "$dependency" == "libdvdread" ]]; then
      apply_libdvdread_source_patches "$source_dir"
    fi
  fi

  local slice_definition
  for slice_definition in $(selected_apple_build_slices); do
    local slice_name sdk target_triple expected_platform xcconfig_sdk_condition
    IFS='|' read -r slice_name sdk target_triple expected_platform xcconfig_sdk_condition <<< "$slice_definition"
    build_libdvd_slice \
      "$dependency" "$slice_name" "$sdk" "$target_triple" \
      "$source_dir" "$build_root" "$install_root" "$dry_run"
  done

  if [[ "$dry_run" != "1" ]]; then
    echo "Built ${dependency} Apple slices under: ${install_root}"
  fi
}

main() {
  local mode="build"
  local dry_run="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run="1"
        shift
        ;;
      --build-dav1d)
        mode="build-dav1d"
        shift
        ;;
      --build-libbluray)
        mode="build-libbluray"
        shift
        ;;
      --build-libdvdread)
        mode="build-libdvdread"
        shift
        ;;
      --build-libdvdnav)
        mode="build-libdvdnav"
        shift
        ;;
      --print-swiftpm-flags)
        mode="print-swiftpm-flags"
        shift
        print_swiftpm_flags "${1:-}"
        exit 0
        ;;
      --print-artifact-swiftpm-flags)
        mode="print-artifact-swiftpm-flags"
        shift
        print_artifact_swiftpm_flags "${1:-}" "${2:-}"
        exit 0
        ;;
      --print-artifact-env)
        mode="print-artifact-env"
        shift
        print_artifact_env "${1:-}" "${2:-}"
        exit 0
        ;;
      --print-xcconfig)
        mode="print-xcconfig"
        shift
        print_xcconfig "${1:-}"
        exit 0
        ;;
      --print-xcconfig-root)
        mode="print-xcconfig-root"
        shift
        print_xcconfig_root "${1:-}"
        exit 0
        ;;
      --print-artifact-xcconfig-root)
        mode="print-artifact-xcconfig-root"
        shift
        print_artifact_xcconfig_root "${1:-}"
        exit 0
        ;;
      --print-artifact-manifest-root)
        mode="print-artifact-manifest-root"
        shift
        print_artifact_manifest_root "${1:-}"
        exit 0
        ;;
      --package-artifact-root)
        mode="package-artifact-root"
        shift
        package_artifact_root "${1:-}" "${2:-}"
        exit 0
        ;;
      --embed-artifact-runtime-capabilities)
        mode="embed-artifact-runtime-capabilities"
        shift
        embed_artifact_runtime_capabilities "${1:-}"
        exit 0
        ;;
      --print-no-space-build-env)
        mode="print-no-space-build-env"
        shift
        print_no_space_build_env "${1:-}"
        exit 0
        ;;
      --prepare-no-space-build-env)
        mode="prepare-no-space-build-env"
        shift
        prepare_no_space_build_env "${1:-}"
        exit 0
        ;;
      --verify-install)
        mode="verify-install"
        shift
        verify_install "${1:-}"
        exit 0
        ;;
      --verify-install-root)
        mode="verify-install-root"
        shift
        verify_install_root "${1:-}"
        exit 0
        ;;
      --verify-artifact-root)
        mode="verify-artifact-root"
        shift
        verify_artifact_root "$@"
        exit 0
        ;;
      --verify-release-artifact-root)
        mode="verify-release-artifact-root"
        shift
        verify_release_artifact_root "$@"
        exit 0
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

  if [[ "$mode" != "build" ]]; then
    if [[ "$mode" == "build-dav1d" ]]; then
      build_dav1d "$dry_run"
      exit 0
    fi
    if [[ "$mode" == "build-libbluray" ]]; then
      build_libbluray "$dry_run"
      exit 0
    fi
    if [[ "$mode" == "build-libdvdread" ]]; then
      build_libdvd_dependency "libdvdread" "$dry_run"
      exit 0
    fi
    if [[ "$mode" == "build-libdvdnav" ]]; then
      build_libdvd_dependency "libdvdnav" "$dry_run"
      exit 0
    fi
    echo "error: unsupported mode: $mode" >&2
    exit 64
  fi

  local package_root
  package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local build_root="${NSURATOR_PLAYER_CORE_FFMPEG_BUILD_DIR:-${package_root}/.build/ffmpeg-visionos}"
  local install_root="${NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR:-${build_root}/install}"
  local source_dir="${FFMPEG_SOURCE_DIR:-}"
  if [[ -z "$source_dir" ]]; then
    if [[ "$dry_run" == "1" ]]; then
      source_dir="${build_root}/sources/ffmpeg"
    else
      echo "error: FFMPEG_SOURCE_DIR is required" >&2
      exit 64
    fi
  fi
  if [[ "$dry_run" != "1" && ! -f "${source_dir}/configure" ]]; then
    echo "error: FFMPEG_SOURCE_DIR does not contain configure: ${source_dir}" >&2
    exit 66
  fi

  if [[ "$dry_run" != "1" ]]; then
    validate_ffmpeg_build_paths_without_whitespace \
      "FFMPEG_SOURCE_DIR" "$source_dir" \
      "NSURATOR_PLAYER_CORE_FFMPEG_BUILD_DIR" "$build_root" \
      "NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR" "$install_root" \
      "NSURATOR_PLAYER_CORE_DEP_PREFIX" "${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}"
  fi

  local source_patch_script="${package_root}/scripts/apply-ffmpeg-source-patches.sh"
  if [[ "$dry_run" == "1" ]]; then
    printf '%s %s\n' "$source_patch_script" "$source_dir"
  else
    "$source_patch_script" "$source_dir"
  fi

  local slice_definition
  for slice_definition in $(selected_apple_build_slices); do
    local slice_name sdk target_triple expected_platform xcconfig_sdk_condition
    IFS='|' read -r slice_name sdk target_triple expected_platform xcconfig_sdk_condition <<< "$slice_definition"
    build_slice "$slice_name" "$sdk" "$target_triple" "$source_dir" "$build_root" "$install_root" "$dry_run"
  done

  local default_swiftpm_slice
  default_swiftpm_slice="$(first_apple_slice_name)"

  if [[ "$(swiftpm_link_mode)" == "framework" && -z "${NSURATOR_PLAYER_CORE_FFMPEG_FRAMEWORK_DIR:-}" ]]; then
    # Framework mode links a framework that only --package-artifact-root builds.
    echo "Built FFmpeg Apple slices under: ${install_root}"
    echo "SwiftPM framework link mode: run --package-artifact-root to build the runtime framework, then --print-artifact-env."
    return 0
  fi

  if [[ "$dry_run" == "1" ]]; then
    echo "# SwiftPM flags for a linked ${default_swiftpm_slice} build"
    local swiftpm_dep_prefix=""
    if [[ -n "${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}" ]]; then
      swiftpm_dep_prefix="$(dependency_prefix_for_slice "$default_swiftpm_slice")"
    fi
    print_swiftpm_flags "${install_root}/${default_swiftpm_slice}" "$swiftpm_dep_prefix"
  else
    echo "Built FFmpeg Apple slices under: ${install_root}"
    echo "SwiftPM flags for ${default_swiftpm_slice}:"
    local swiftpm_dep_prefix=""
    if [[ -n "${NSURATOR_PLAYER_CORE_DEP_PREFIX:-}" ]]; then
      swiftpm_dep_prefix="$(dependency_prefix_for_slice "$default_swiftpm_slice")"
    fi
    print_swiftpm_flags "${install_root}/${default_swiftpm_slice}" "$swiftpm_dep_prefix"
  fi
}

main "$@"
