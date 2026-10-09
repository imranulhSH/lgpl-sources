#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=media_tools_artifact_common.sh
source "$SCRIPT_DIR/media_tools_artifact_common.sh"

SOURCE_LOCK="$NSURATOR_MEDIA_TOOLS_ROOT/Config/media-tools-sources.json"
SOURCE_CACHE=""
WORK_ROOT=""
DIST_ROOT="$NSURATOR_MEDIA_TOOLS_ROOT/.build/media-tools-artifacts/dist"
JOBS="$(/usr/sbin/sysctl -n hw.logicalcpu 2>/dev/null || printf '4')"
DRY_RUN=false

usage() {
  cat <<'USAGE'
usage: script/build_media_tools_artifact.sh [options]

Options:
  --dry-run
  --source-cache <directory>
  --work-root <directory>
  --dist-root <directory>
  --jobs <count>
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --source-cache) SOURCE_CACHE="${2:-}"; shift 2 ;;
    --work-root) WORK_ROOT="${2:-}"; shift 2 ;;
    --dist-root) DIST_ROOT="${2:-}"; shift 2 ;;
    --jobs) JOBS="${2:-}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; mt_die "unknown argument: $1" ;;
  esac
done

[[ -f "$SOURCE_LOCK" ]] || mt_die "media-tools source lock is unavailable: $SOURCE_LOCK"
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || mt_die "--jobs must be a positive integer"

source_value() {
  mt_json_value "$SOURCE_LOCK" "sources.$1.$2"
}

ARTIFACT_VERSION="$(mt_json_value "$SOURCE_LOCK" artifactVersion)"
ARCHITECTURE="$(mt_json_value "$SOURCE_LOCK" architecture)"
MINIMUM_MACOS_VERSION="$(mt_json_value "$SOURCE_LOCK" minimumMacOSVersion)"

if [[ "$DRY_RUN" == true ]]; then
  printf 'artifactVersion=%s\n' "$ARTIFACT_VERSION"
  printf 'architecture=%s\n' "$ARCHITECTURE"
  printf 'minimumMacOSVersion=%s\n' "$MINIMUM_MACOS_VERSION"
  printf 'licenseFamily=%s\n' "$(mt_json_value "$SOURCE_LOCK" licenseFamily)"
  for source_key in ffmpeg libass freetype fribidi harfbuzz libunibreak libpng; do
    printf '%s=%s\n' "$source_key" "$(source_value "$source_key" version)"
  done
  exit 0
fi

for required_command in clang clang++ curl make meson ninja pkg-config tar xcrun zip; do
  mt_require_command "$required_command"
done

if [[ -z "$WORK_ROOT" ]]; then
  WORK_ROOT="$(/usr/bin/mktemp -d /tmp/nsurator-media-tools-artifact.XXXXXX)"
else
  [[ "$WORK_ROOT" == /* ]] || mt_die "--work-root must be an absolute path"
  [[ ! -e "$WORK_ROOT" ]] || mt_die "--work-root must not already exist: $WORK_ROOT"
  /bin/mkdir -p "$WORK_ROOT"
fi
if [[ "$DIST_ROOT" != /* ]]; then
  DIST_ROOT="$NSURATOR_MEDIA_TOOLS_ROOT/$DIST_ROOT"
fi
if [[ -n "$SOURCE_CACHE" && "$SOURCE_CACHE" != /* ]]; then
  SOURCE_CACHE="$NSURATOR_MEDIA_TOOLS_ROOT/$SOURCE_CACHE"
fi

ARCHIVE_ROOT="$WORK_ROOT/source-archives"
SOURCE_ROOT="$WORK_ROOT/sources"
BUILD_ROOT="$WORK_ROOT/build"
PREFIX_ROOT="$WORK_ROOT/prefix"
LOG_ROOT="$WORK_ROOT/logs"
ARTIFACT_DIRECTORY_NAME="nsurator-media-tools-$ARTIFACT_VERSION"
ARTIFACT_ROOT="$DIST_ROOT/$ARTIFACT_DIRECTORY_NAME"
ARCHIVE_PATH="$DIST_ROOT/$ARTIFACT_DIRECTORY_NAME.tar.gz"
/bin/mkdir -p "$ARCHIVE_ROOT" "$SOURCE_ROOT" "$BUILD_ROOT" "$PREFIX_ROOT" "$LOG_ROOT" "$DIST_ROOT"

fetch_source_archive() {
  local source_key="$1"
  local archive_name source_url expected_sha destination actual_sha
  archive_name="$(source_value "$source_key" archiveName)"
  source_url="$(source_value "$source_key" url)"
  expected_sha="$(source_value "$source_key" sha256)"
  destination="$ARCHIVE_ROOT/$archive_name"

  if [[ -n "$SOURCE_CACHE" && -f "$SOURCE_CACHE/$archive_name" ]]; then
    /bin/cp "$SOURCE_CACHE/$archive_name" "$destination"
  else
    /usr/bin/curl -fL --retry 5 --retry-delay 2 "$source_url" -o "$destination.download"
    /bin/mv "$destination.download" "$destination"
  fi
  actual_sha="$(mt_sha256 "$destination")"
  [[ "$actual_sha" == "$expected_sha" ]] || mt_die "source checksum mismatch: $archive_name"
  printf '%s\n' "$destination"
}

extract_source_archive() {
  local archive="$1"
  case "$archive" in
    *.tar.xz) /usr/bin/tar -xJf "$archive" -C "$SOURCE_ROOT" ;;
    *.tar.gz) /usr/bin/tar -xzf "$archive" -C "$SOURCE_ROOT" ;;
    *) mt_die "unsupported source archive: $archive" ;;
  esac
}

for source_key in ffmpeg libass freetype fribidi harfbuzz libunibreak libpng; do
  extract_source_archive "$(fetch_source_archive "$source_key")"
done

FFMPEG_SOURCE="$SOURCE_ROOT/ffmpeg-$(source_value ffmpeg version)"
LIBASS_SOURCE="$SOURCE_ROOT/libass-$(source_value libass version)"
FREETYPE_SOURCE="$SOURCE_ROOT/freetype-$(source_value freetype version)"
FRIBIDI_SOURCE="$SOURCE_ROOT/fribidi-$(source_value fribidi version)"
HARFBUZZ_SOURCE="$SOURCE_ROOT/harfbuzz-$(source_value harfbuzz version)"
LIBUNIBREAK_SOURCE="$SOURCE_ROOT/libunibreak-$(source_value libunibreak version)"
LIBPNG_SOURCE="$SOURCE_ROOT/libpng-$(source_value libpng version)"

for required_file in \
  "$FFMPEG_SOURCE/configure" \
  "$LIBASS_SOURCE/meson.build" \
  "$FREETYPE_SOURCE/meson.build" \
  "$FRIBIDI_SOURCE/meson.build" \
  "$HARFBUZZ_SOURCE/meson.build" \
  "$LIBUNIBREAK_SOURCE/configure" \
  "$LIBPNG_SOURCE/configure"; do
  [[ -f "$required_file" ]] || mt_die "extracted source is incomplete: $required_file"
done

export MACOSX_DEPLOYMENT_TARGET="$MINIMUM_MACOS_VERSION"
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
export CC="$(xcrun --find clang)"
export CXX="$(xcrun --find clang++)"
export AR="$(xcrun --find ar)"
export RANLIB="$(xcrun --find ranlib)"
export STRIP="$(xcrun --find strip)"
export CFLAGS="-O2 -arch $ARCHITECTURE -isysroot $SDKROOT -mmacosx-version-min=$MINIMUM_MACOS_VERSION"
export CXXFLAGS="$CFLAGS"
export CPPFLAGS="-I$PREFIX_ROOT/include"
export LDFLAGS="-arch $ARCHITECTURE -isysroot $SDKROOT -mmacosx-version-min=$MINIMUM_MACOS_VERSION -L$PREFIX_ROOT/lib"
export PKG_CONFIG_PATH="$PREFIX_ROOT/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$PREFIX_ROOT/lib/pkgconfig:/usr/lib/pkgconfig"

run_logged() {
  local stage_name="$1"
  shift
  printf 'building %s\n' "$stage_name"
  "$@" >"$LOG_ROOT/$stage_name.log" 2>&1 || {
    /usr/bin/tail -n 80 "$LOG_ROOT/$stage_name.log" >&2
    mt_die "$stage_name build failed; full log: $LOG_ROOT/$stage_name.log"
  }
}

/bin/mkdir -p "$BUILD_ROOT/libpng"
(
  cd "$BUILD_ROOT/libpng"
  run_logged libpng-configure \
    "$LIBPNG_SOURCE/configure" \
    --prefix="$PREFIX_ROOT" \
    --disable-shared \
    --enable-static \
    --disable-dependency-tracking
)
run_logged libpng-build /usr/bin/make -C "$BUILD_ROOT/libpng" -j "$JOBS"
run_logged libpng-install /usr/bin/make -C "$BUILD_ROOT/libpng" install

run_logged freetype-configure \
  meson setup "$BUILD_ROOT/freetype" "$FREETYPE_SOURCE" \
  --prefix="$PREFIX_ROOT" \
  --libdir=lib \
  --buildtype=release \
  --default-library=static \
  -Dbrotli=disabled \
  -Dbzip2=disabled \
  -Dharfbuzz=disabled \
  -Dpng=enabled \
  -Dtests=disabled \
  -Dzlib=system
run_logged freetype-build meson compile -C "$BUILD_ROOT/freetype" -j "$JOBS"
run_logged freetype-install meson install -C "$BUILD_ROOT/freetype"

run_logged fribidi-configure \
  meson setup "$BUILD_ROOT/fribidi" "$FRIBIDI_SOURCE" \
  --prefix="$PREFIX_ROOT" \
  --libdir=lib \
  --buildtype=release \
  --default-library=static \
  -Dbin=false \
  -Ddocs=false \
  -Dtests=false
run_logged fribidi-build meson compile -C "$BUILD_ROOT/fribidi" -j "$JOBS"
run_logged fribidi-install meson install -C "$BUILD_ROOT/fribidi"

run_logged harfbuzz-configure \
  meson setup "$BUILD_ROOT/harfbuzz" "$HARFBUZZ_SOURCE" \
  --prefix="$PREFIX_ROOT" \
  --libdir=lib \
  --buildtype=release \
  --default-library=static \
  -Dbenchmark=disabled \
  -Dcairo=disabled \
  -Dchafa=disabled \
  -Dcoretext=disabled \
  -Ddocs=disabled \
  -Dfreetype=enabled \
  -Dglib=disabled \
  -Dgobject=disabled \
  -Dgpu=disabled \
  -Dgpu_demo=disabled \
  -Dgraphite2=disabled \
  -Dicu=disabled \
  -Dintrospection=disabled \
  -Dpng=disabled \
  -Draster=disabled \
  -Dsubset=disabled \
  -Dtests=disabled \
  -Dutilities=disabled \
  -Dvector=disabled \
  -Dzlib=disabled
run_logged harfbuzz-build meson compile -C "$BUILD_ROOT/harfbuzz" -j "$JOBS"
run_logged harfbuzz-install meson install -C "$BUILD_ROOT/harfbuzz"

/bin/mkdir -p "$BUILD_ROOT/libunibreak"
(
  cd "$BUILD_ROOT/libunibreak"
  run_logged libunibreak-configure \
    "$LIBUNIBREAK_SOURCE/configure" \
    --prefix="$PREFIX_ROOT" \
    --disable-shared \
    --enable-static \
    --disable-dependency-tracking
)
run_logged libunibreak-build /usr/bin/make -C "$BUILD_ROOT/libunibreak" -j "$JOBS"
run_logged libunibreak-install /usr/bin/make -C "$BUILD_ROOT/libunibreak" install

run_logged libass-configure \
  meson setup "$BUILD_ROOT/libass" "$LIBASS_SOURCE" \
  --prefix="$PREFIX_ROOT" \
  --libdir=lib \
  --buildtype=release \
  --default-library=static \
  -Dasm=enabled \
  -Dcompare=disabled \
  -Dcoretext=enabled \
  -Dfontconfig=disabled \
  -Dfuzz=disabled \
  -Dlibunibreak=enabled \
  -Dprofile=disabled \
  -Dtest=disabled
run_logged libass-build meson compile -C "$BUILD_ROOT/libass" -j "$JOBS"
run_logged libass-install meson install -C "$BUILD_ROOT/libass"

FFMPEG_CONFIGURE_FLAGS=(
  "--prefix=$PREFIX_ROOT"
  "--arch=$ARCHITECTURE"
  "--cc=$CC"
  "--cxx=$CXX"
  "--extra-cflags=$CFLAGS $CPPFLAGS"
  "--extra-cxxflags=$CXXFLAGS $CPPFLAGS"
  "--extra-ldflags=$LDFLAGS"
  "--extra-libs=-lc++"
  "--pkg-config-flags=--static"
  --disable-debug
  --disable-doc
  --disable-ffplay
  --disable-gpl
  --disable-nonfree
  --disable-shared
  --enable-audiotoolbox
  --enable-libass
  --enable-pic
  --enable-securetransport
  --enable-static
  --enable-videotoolbox
)
(
  cd "$FFMPEG_SOURCE"
  run_logged ffmpeg-configure ./configure "${FFMPEG_CONFIGURE_FLAGS[@]}"
)
run_logged ffmpeg-build /usr/bin/make -C "$FFMPEG_SOURCE" -j "$JOBS"
run_logged ffmpeg-install /usr/bin/make -C "$FFMPEG_SOURCE" install

[[ -x "$PREFIX_ROOT/bin/ffmpeg" && -x "$PREFIX_ROOT/bin/ffprobe" ]] \
  || mt_die "FFmpeg build did not produce ffmpeg and ffprobe"

/bin/rm -rf "$ARTIFACT_ROOT"
/bin/rm -f "$ARCHIVE_PATH"
/bin/mkdir -p \
  "$ARTIFACT_ROOT/bin" \
  "$ARTIFACT_ROOT/licenses" \
  "$ARTIFACT_ROOT/relink" \
  "$ARTIFACT_ROOT/source-archives"
for tool_name in ffmpeg ffprobe; do
  /bin/cp "$PREFIX_ROOT/bin/$tool_name" "$ARTIFACT_ROOT/bin/$tool_name"
  "$STRIP" -x "$ARTIFACT_ROOT/bin/$tool_name"
  /usr/bin/codesign --force --sign - --timestamp=none "$ARTIFACT_ROOT/bin/$tool_name" >/dev/null
done

/bin/cp "$FFMPEG_SOURCE/LICENSE.md" "$ARTIFACT_ROOT/licenses/FFmpeg-LICENSE.md"
/bin/cp "$FFMPEG_SOURCE/COPYING.LGPLv2.1" "$ARTIFACT_ROOT/licenses/FFmpeg-COPYING.LGPLv2.1"
/bin/cp "$LIBASS_SOURCE/COPYING" "$ARTIFACT_ROOT/licenses/libass-COPYING"
/bin/cp "$FREETYPE_SOURCE/LICENSE.TXT" "$ARTIFACT_ROOT/licenses/FreeType-LICENSE.TXT"
/bin/cp "$FRIBIDI_SOURCE/COPYING" "$ARTIFACT_ROOT/licenses/FriBidi-COPYING"
/bin/cp "$HARFBUZZ_SOURCE/COPYING" "$ARTIFACT_ROOT/licenses/HarfBuzz-COPYING"
/bin/cp "$LIBUNIBREAK_SOURCE/LICENCE" "$ARTIFACT_ROOT/licenses/libunibreak-LICENCE"
/bin/cp "$LIBPNG_SOURCE/LICENSE" "$ARTIFACT_ROOT/licenses/libpng-LICENSE"
/bin/cp \
  "$NSURATOR_MEDIA_TOOLS_ROOT/Sources/NsuratorNative/Resources/ThirdPartyPlayback/MEDIA-TOOLS-NOTICE.md" \
  "$ARTIFACT_ROOT/licenses/MEDIA-TOOLS-NOTICE.md"
/bin/cp "$SOURCE_LOCK" "$ARTIFACT_ROOT/media-tools-sources.json"
/bin/cp "$ARCHIVE_ROOT"/* "$ARTIFACT_ROOT/source-archives/"
/bin/cp "$0" "$ARTIFACT_ROOT/relink/build_media_tools_artifact.sh"
/bin/cp "$SCRIPT_DIR/media_tools_artifact_common.sh" "$ARTIFACT_ROOT/relink/media_tools_artifact_common.sh"

{
  printf 'FFmpeg configure flags:\n'
  printf '  %q' "${FFMPEG_CONFIGURE_FLAGS[@]}"
  printf '\n\nCompiler:\n'
  "$CC" --version | /usr/bin/head -n 1
  printf '\nSDK:\n'
  xcrun --sdk macosx --show-sdk-path
} >"$ARTIFACT_ROOT/build-configuration.txt"

"$ARTIFACT_ROOT/bin/ffmpeg" -hide_banner -version >"$ARTIFACT_ROOT/ffmpeg-version.txt"
"$ARTIFACT_ROOT/bin/ffmpeg" -hide_banner -buildconf >"$ARTIFACT_ROOT/ffmpeg-buildconf.txt"
if /usr/bin/grep -Eq -- '--enable-(gpl|nonfree|libx264|libx265)' "$ARTIFACT_ROOT/ffmpeg-buildconf.txt"; then
  mt_die "forbidden GPL or x264/x265 configure option found in built FFmpeg"
fi
if "$ARTIFACT_ROOT/bin/ffmpeg" -hide_banner -encoders 2>/dev/null | \
    /usr/bin/grep -Eq '(^|[[:space:]])libx26[45]([[:space:]]|$)'; then
  mt_die "forbidden libx264/libx265 encoder found in built FFmpeg"
fi
mt_assert_system_dependencies_only "$ARTIFACT_ROOT/bin/ffmpeg"
mt_assert_system_dependencies_only "$ARTIFACT_ROOT/bin/ffprobe"
for required_filter in ass overlay subtitles; do
  mt_filter_is_available "$ARTIFACT_ROOT/bin/ffmpeg" "$required_filter" \
    || mt_die "required FFmpeg filter is unavailable: $required_filter"
done

(
  cd "$DIST_ROOT"
  COPYFILE_DISABLE=1 /usr/bin/tar -czf "$ARCHIVE_PATH" "$ARTIFACT_DIRECTORY_NAME"
)

printf 'artifactRoot=%s\n' "$ARTIFACT_ROOT"
printf 'archivePath=%s\n' "$ARCHIVE_PATH"
printf 'ffmpegSHA256=%s\n' "$(mt_sha256 "$ARTIFACT_ROOT/bin/ffmpeg")"
printf 'ffprobeSHA256=%s\n' "$(mt_sha256 "$ARTIFACT_ROOT/bin/ffprobe")"
printf 'archiveSHA256=%s\n' "$(mt_sha256 "$ARCHIVE_PATH")"
printf 'workRoot=%s\n' "$WORK_ROOT"
