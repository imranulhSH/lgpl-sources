#!/bin/bash
# Builds the visionOS FFmpeg runtime artifact (xros-arm64 and xrsimulator-arm64)
# from the SHA-locked source archives the tvOS build already downloaded.
# Nothing is downloaded and nothing outside this repository is written.
#
#   scripts/build_ffmpeg_visionos.sh            # build + verify both slices
#   scripts/build_ffmpeg_visionos.sh build      # same
#   scripts/build_ffmpeg_visionos.sh verify     # verify the existing artifact only
#   scripts/build_ffmpeg_visionos.sh clean      # remove artifacts/ffmpeg-work (keeps artifacts/ffmpeg)
#
# Profile (same as the macOS/tvOS shipping artifact): FFmpeg 8.1.2 'base' link
# profile, static, LGPL only (no --enable-gpl / --enable-version3 / --enable-nonfree),
# --enable-libdav1d, --enable-libbluray (libudfread embedded), --enable-videotoolbox,
# --disable-network. Networking stays in the app's own connectors (custom AVIO).
# No library may name a directory of the Mac that built it (V-D57): FFmpeg's
# configure line and source paths are relative, and verify refuses any other.
#
# Environment:
#   NV_FFMPEG_SLICES    slices to build (default "xros-arm64 xrsimulator-arm64")
#   NV_FFMPEG_ARCHIVES  directory with the four archives
#                       (default ~/Documents/nsurator-player-core-tvos/.build/tvos-runtime/archives)
#   NV_FFMPEG_TOOLING   directory with meson, ninja, pkg-config
#                       (default ~/Documents/nsurator-player-core-tvos/.build/tooling/venv/bin, then PATH)
#   NV_FFMPEG_JOBS      parallel compile jobs (default 4)
#   NV_FFMPEG_MIN_OS    minimum visionOS version (default 27.0, the app's deployment target)
#   NV_PLAYER_CORE      player-core checkout used for the shim link check (default
#                       ../nsurator-player-core-visionos, the worktree the app builds against)
#   NV_FFMPEG_WORK / NV_FFMPEG_OUT  override the work and output roots (e.g. for a side-by-side rebuild)
#
# Outputs: artifacts/ffmpeg/<slice>/{include,lib,licenses,BUILD-INFO.txt,swiftpm.env}
# Work:    artifacts/ffmpeg-work/{sources,build,stage,verify,logs}
# See docs/ffmpeg-visionos.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FF_DIR="$ROOT/scripts/ffmpeg"
LOCK="$FF_DIR/sources.lock.json"
PATCH_DIR="$FF_DIR/patches"
ARCHIVES="${NV_FFMPEG_ARCHIVES:-$HOME/Documents/nsurator-player-core-tvos/.build/tvos-runtime/archives}"
TOOLING="${NV_FFMPEG_TOOLING:-$HOME/Documents/nsurator-player-core-tvos/.build/tooling/venv/bin}"
PLAYER_CORE="${NV_PLAYER_CORE:-$(cd "$ROOT/.." && pwd)/nsurator-player-core-visionos}"
WORK="${NV_FFMPEG_WORK:-$ROOT/artifacts/ffmpeg-work}"
OUT="${NV_FFMPEG_OUT:-$ROOT/artifacts/ffmpeg}"
JOBS="${NV_FFMPEG_JOBS:-4}"
MIN_OS="${NV_FFMPEG_MIN_OS:-27.0}"
SLICES="${NV_FFMPEG_SLICES:-xros-arm64 xrsimulator-arm64}"
NICE="nice -n 10"

# The sibling venv's Python must not gain .pyc files from our runs.
export PYTHONDONTWRITEBYTECODE=1

FFMPEG_EXTRA_FLAGS="--enable-libdav1d --disable-network"

log() { printf '[ffmpeg-visionos] %s\n' "$*" >&2; }
die() { printf '[ffmpeg-visionos] error: %s\n' "$*" >&2; exit 1; }

case "$ROOT" in *" "*) die "FFmpeg configure cannot build in a path containing spaces: $ROOT";; esac

lock_field() { # component field
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sources"][sys.argv[2]][sys.argv[3]])' "$LOCK" "$1" "$2"
}

slice_sdk() {
  case "$1" in
    xros-arm64) echo xros;;
    xrsimulator-arm64) echo xrsimulator;;
    *) die "unknown slice: $1 (expected xros-arm64 or xrsimulator-arm64)";;
  esac
}
slice_triple() {
  case "$1" in
    xros-arm64) echo "arm64-apple-xros${MIN_OS}";;
    xrsimulator-arm64) echo "arm64-apple-xros${MIN_OS}-simulator";;
  esac
}
slice_platform_id() { # LC_BUILD_VERSION platform number
  case "$1" in
    xros-arm64) echo 11;;
    xrsimulator-arm64) echo 12;;
  esac
}

# ---------------------------------------------------------------- tools

MESON=""; NINJA=""; PKG_CONFIG_BIN=""
find_tool() { # name
  if [[ -x "$TOOLING/$1" ]]; then echo "$TOOLING/$1"; return 0; fi
  command -v "$1" 2>/dev/null || true
}
check_tools() {
  local missing=()
  MESON="$(find_tool meson)"; [[ -n "$MESON" ]] || missing+=("meson")
  NINJA="$(find_tool ninja)"; [[ -n "$NINJA" ]] || missing+=("ninja")
  PKG_CONFIG_BIN="$(find_tool pkg-config)"; [[ -n "$PKG_CONFIG_BIN" ]] || missing+=("pkg-config")
  local t
  for t in make patch python3 shasum tar lipo otool nm xcrun; do
    command -v "$t" >/dev/null 2>&1 || missing+=("$t")
  done
  if (( ${#missing[@]} )); then
    die "missing build tools: ${missing[*]} (looked in $TOOLING and PATH; nothing is downloaded)"
  fi
  export PATH="$(dirname "$NINJA"):$PATH"
  CLANG="$(xcrun -f clang)"
  AR="$(xcrun -f ar)"
  log "meson $("$MESON" --version), ninja $("$NINJA" --version), pkg-config $(PKG_CONFIG_PATH=/var/empty "$PKG_CONFIG_BIN" --version 2>/dev/null)"
}

# ---------------------------------------------------------------- sources

patch_set_digest() {
  ( cd "$PATCH_DIR" && cat series $(awk '!/^#/ && NF==2 {print $2}' series) | shasum -a 256 | cut -c1-64 )
}

verify_archives() {
  local c archive want got
  for c in ffmpeg dav1d libbluray libudfread; do
    archive="$ARCHIVES/$(lock_field "$c" archiveName)"
    [[ -f "$archive" ]] || die "missing source archive: $archive (run the tvOS prepare step once; this script never downloads)"
    want="$(lock_field "$c" sha256)"
    got="$(shasum -a 256 "$archive" | cut -c1-64)"
    [[ "$got" == "$want" ]] || die "SHA-256 mismatch for $archive: got $got, lock says $want"
    log "verified $c $(lock_field "$c" version) sha256=$got"
  done
}

apply_patch_strict() { # source-dir patch-file
  local dir="$1" file="$2"
  if patch -d "$dir" -p1 -N --dry-run <"$file" >/dev/null 2>&1; then
    patch -d "$dir" -p1 -N --quiet <"$file"
    log "applied $(basename "$file")"
  elif patch -d "$dir" -p1 -R --dry-run <"$file" >/dev/null 2>&1; then
    log "already applied $(basename "$file")"
  else
    die "source is incompatible with $(basename "$file")"
  fi
}

prepare_sources() {
  local src="$WORK/sources" digest marker want
  digest="$(patch_set_digest)"
  want="$(for c in ffmpeg dav1d libbluray libudfread; do lock_field "$c" sha256; done | shasum -a 256 | cut -c1-64) $digest"
  marker="$src/.nv-prepared"
  if [[ -f "$marker" && "$(cat "$marker")" == "$want" ]]; then
    log "sources already prepared (archives + patch set unchanged)"
    return 0
  fi
  log "extracting sources into $src"
  rm -rf "$src"; mkdir -p "$src"
  local c
  for c in ffmpeg dav1d libbluray libudfread; do
    tar -xf "$ARCHIVES/$(lock_field "$c" archiveName)" -C "$src"
    [[ -d "$src/$c-$(lock_field "$c" version)" ]] || die "archive for $c did not unpack to $c-$(lock_field "$c" version)"
  done
  # libbluray builds libudfread as an embedded meson subproject from contrib/.
  local bluray="$src/libbluray-$(lock_field libbluray version)"
  rm -rf "$bluray/contrib/libudfread"
  cp -Rp "$src/libudfread-$(lock_field libudfread version)" "$bluray/contrib/libudfread"
  local comp file
  while read -r comp file; do
    [[ -z "$comp" || "$comp" == \#* ]] && continue
    case "$comp" in
      ffmpeg) apply_patch_strict "$src/ffmpeg-$(lock_field ffmpeg version)" "$PATCH_DIR/$file";;
      libbluray) apply_patch_strict "$bluray" "$PATCH_DIR/$file";;
      *) die "unknown component in patches/series: $comp";;
    esac
  done <"$PATCH_DIR/series"
  grep -q NPC_LIBBLURAY_DISABLE_AACS_BDPLUS_DLOPEN "$bluray/src/libbluray/disc/aacs.c" \
    || die "libbluray fail-closed decryption patch marker missing"
  grep -q NPC_FFMPEG_VISIONOS_VIDEOTOOLBOX "$src/ffmpeg-$(lock_field ffmpeg version)/libavcodec/videotoolbox.c" \
    || die "FFmpeg visionOS VideoToolbox patch marker missing"
  printf '%s' "$want" >"$marker"
}

# ---------------------------------------------------------------- build steps

write_cross_file() { # file triple sysroot meson-system
  local file="$1" triple="$2" sysroot="$3" system="$4"
  mkdir -p "$(dirname "$file")"
  cat >"$file" <<CROSS
[binaries]
c = ['$CLANG', '-target', '$triple', '-isysroot', '$sysroot', '-fPIC']
ar = '$AR'

[built-in options]
c_args = ['-target', '$triple', '-isysroot', '$sysroot', '-fPIC']
c_link_args = ['-target', '$triple', '-isysroot', '$sysroot']

[properties]
needs_exe_wrapper = true

[host_machine]
system = '$system'
cpu_family = 'aarch64'
cpu = 'arm64'
endian = 'little'
CROSS
}

meson_build() { # name source build cross prefix logfile options...
  local name="$1" source="$2" build="$3" cross="$4" prefix="$5" logfile="$6"; shift 6
  log "$name: meson setup ($(basename "$build"))"
  local setup=(setup "$build" "$source" --cross-file "$cross" "--prefix=$prefix" --libdir=lib
    --buildtype=release -Ddefault_library=static --wrap-mode=nodownload "$@")
  if [[ -f "$build/build.ninja" ]]; then setup+=(--reconfigure); fi
  {
    $NICE "$MESON" "${setup[@]}"
    $NICE "$MESON" compile -C "$build" -j "$JOBS"
    $NICE "$MESON" install -C "$build"
  } >>"$logfile" 2>&1 || { tail -n 40 "$logfile" >&2; die "$name build failed (log: $logfile)"; }
}

build_slice() {
  local slice="$1" sdk triple sysroot
  sdk="$(slice_sdk "$slice")"; triple="$(slice_triple "$slice")"
  sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)"
  local src="$WORK/sources" build="$WORK/build/$slice" stage="$WORK/stage/$slice"
  local logs="$WORK/logs"; mkdir -p "$logs" "$build"
  local logfile="$logs/$slice.log"; : >"$logfile"
  log "== $slice ($triple, $(basename "$sysroot"))"
  rm -rf "$stage"; mkdir -p "$stage"

  # dav1d (BSD-2): meson host system 'darwin' gives the Mach-O asm symbol prefix.
  write_cross_file "$build/dav1d.cross" "$triple" "$sysroot" darwin
  meson_build dav1d "$src/dav1d-$(lock_field dav1d version)" "$build/dav1d" "$build/dav1d.cross" "$stage" "$logfile" \
    -Denable_tools=false -Denable_tests=false -Denable_examples=false -Denable_docs=false

  # libbluray (+ embedded libudfread): 'ios' keeps it off the macOS-only
  # DiskArbitration / mount_darwin path, as the tvOS build does.
  write_cross_file "$build/libbluray.cross" "$triple" "$sysroot" ios
  meson_build libbluray "$src/libbluray-$(lock_field libbluray version)" "$build/libbluray" "$build/libbluray.cross" "$stage" "$logfile" \
    -Denable_tools=false -Denable_devtools=false -Denable_examples=false -Denable_docs=false \
    -Dbdj_jar=disabled -Dfreetype=disabled -Dfontconfig=disabled -Dlibxml2=disabled \
    -Dembed_udfread=true --force-fallback-for=libudfread

  # FFmpeg: same configure line as the tvOS/macOS 'base' artifact, minus the
  # obsolete -fembed-bitcode. FFmpeg compiles this line into every library
  # (avcodec_configuration() and the rest) and its asserts carry source paths,
  # so nothing here may name a directory of this Mac (V-D57): configure finds
  # the source through the link src/ and then uses src/ for every path, the
  # SDK comes from SDKROOT, clang and pkg-config are found on PATH, dav1d and
  # libbluray come from pkg-config alone, and the prefix stays at its default
  # while `make install` is pointed at the stage.
  local ffbuild="$build/ffmpeg"; mkdir -p "$ffbuild"
  ln -sfn "$src/ffmpeg-$(lock_field ffmpeg version)" "$ffbuild/src"
  local bin="$WORK/bin"; mkdir -p "$bin"
  ln -sf "$CLANG" "$bin/clang"
  ln -sf "$PKG_CONFIG_BIN" "$bin/pkg-config"
  local configure=(
    src/configure
    --enable-cross-compile --target-os=darwin --arch=arm64
    --cc=clang
    --enable-static --disable-shared --enable-pic
    --disable-programs --disable-doc --disable-debug
    --disable-avdevice --disable-devices
    --enable-avcodec --enable-avformat --enable-avutil --enable-swresample --enable-swscale
    --enable-libbluray --enable-videotoolbox
    --pkg-config=pkg-config
    "--extra-cflags=-target $triple -fPIC" "--extra-ldflags=-target $triple"
  )
  local extra; read -r -a extra <<<"$FFMPEG_EXTRA_FLAGS"
  configure+=("${extra[@]}")
  local ffenv=(env "PATH=$bin:$PATH" "SDKROOT=$sysroot"
    "PKG_CONFIG_LIBDIR=$stage/lib/pkgconfig" "PKG_CONFIG_PATH=$stage/lib/pkgconfig")
  local stamp="$ffbuild/.nv-configure" line want
  line="$(printf '%q ' "${configure[@]}")"
  want="$line SDKROOT=$sysroot CC=$CLANG PKG_CONFIG=$PKG_CONFIG_BIN"
  if [[ ! -f "$ffbuild/config.h" || ! -f "$stamp" || "$(cat "$stamp")" != "$want" ]]; then
    log "ffmpeg: configure"
    ( cd "$ffbuild" && "${ffenv[@]}" $NICE "${configure[@]}" ) >>"$logfile" 2>&1 \
      || { tail -n 40 "$logfile" >&2; tail -n 40 "$ffbuild/ffbuild/config.log" >&2 || true; die "ffmpeg configure failed (log: $logfile)"; }
    printf '%s' "$want" >"$stamp"
  fi
  grep -qx 'SRC_PATH=src' "$ffbuild/ffbuild/config.mak" || die "FFmpeg did not take its source from src/"
  log "ffmpeg: make -j$JOBS"
  { "${ffenv[@]}" $NICE make -C "$ffbuild" -j"$JOBS" && "${ffenv[@]}" $NICE make -C "$ffbuild" install "prefix=$stage"; } >>"$logfile" 2>&1 \
    || { grep -E "error:|Error " "$logfile" | tail -n 30 >&2; die "ffmpeg build failed (log: $logfile)"; }
  grep -q '#define CONFIG_GPL 0' "$ffbuild/config.h" || die "FFmpeg configuration is not LGPL-only"
  grep -q '#define CONFIG_NONFREE 0' "$ffbuild/config.h" || die "FFmpeg configuration enables nonfree code"
  grep -q '#define CONFIG_VERSION3 0' "$ffbuild/config.h" || die "FFmpeg configuration enables (L)GPLv3"
  grep -q '#define CONFIG_LIBDAV1D 1' "$ffbuild/config.h" || die "FFmpeg did not enable libdav1d"
  grep -q '#define CONFIG_LIBBLURAY 1' "$ffbuild/config.h" || die "FFmpeg did not enable libbluray"
  grep -q '#define CONFIG_VIDEOTOOLBOX 1' "$ffbuild/config.h" || die "FFmpeg did not enable VideoToolbox"

  assemble_slice "$slice" "$sysroot" "$line"
}

copy_licenses() { # dest
  local dest="$1" src="$WORK/sources"
  mkdir -p "$dest/patches"
  cp "$src/ffmpeg-$(lock_field ffmpeg version)/LICENSE.md" "$dest/FFmpeg-LICENSE.md"
  cp "$src/ffmpeg-$(lock_field ffmpeg version)/COPYING.LGPLv2.1" "$dest/FFmpeg-COPYING.LGPLv2.1"
  cp "$src/dav1d-$(lock_field dav1d version)/COPYING" "$dest/dav1d-COPYING"
  cp "$src/libbluray-$(lock_field libbluray version)/COPYING" "$dest/libbluray-COPYING"
  cp "$src/libudfread-$(lock_field libudfread version)/COPYING" "$dest/libudfread-COPYING"
  cp "$PATCH_DIR"/series "$PATCH_DIR"/*.patch "$dest/patches/"
  {
    echo "Sources of the libraries in this artifact (unmodified archives plus the patches in patches/):"
    local c
    for c in ffmpeg dav1d libbluray libudfread; do
      printf '%s %s  %s  sha256=%s  license=%s\n' "$c" "$(lock_field "$c" version)" "$(lock_field "$c" url)" \
        "$(lock_field "$c" sha256)" "$(lock_field "$c" license)"
    done
    echo
    echo "FFmpeg is built LGPL-only (no --enable-gpl, --enable-version3 or --enable-nonfree)."
    echo "libudfread is embedded in libbluray.a. libbluray cannot load libaacs/libbdplus/libmmbd (patched off)."
    echo "These libraries are linked statically: an App Store build must ship the LGPL relink"
    echo "materials (app object files + these sources/patches) on request. See docs/ffmpeg-visionos.md."
  } >"$dest/SOURCES.txt"
}

assemble_slice() { # slice sysroot configure-line
  local slice="$1" sysroot="$2" line="$3" stage="$WORK/stage/$1"
  local tmp="$OUT/.$slice.tmp" final="$OUT/$slice"
  rm -rf "$tmp"; mkdir -p "$tmp/lib/pkgconfig"
  cp -R "$stage/include" "$tmp/include"
  cp "$stage"/lib/*.a "$tmp/lib/"
  local pc
  for pc in "$stage"/lib/pkgconfig/*.pc; do
    # meson writes the stage path; FFmpeg, installed with prefix=<stage> on
    # the make line, writes its default /usr/local.
    sed -E -e "s#$stage#$final#g" -e "s#^(prefix|libdir|includedir)=/usr/local#\\1=$final#" \
      "$pc" >"$tmp/lib/pkgconfig/$(basename "$pc")"
  done
  copy_licenses "$tmp/licenses"
  {
    echo "slice=$slice"
    echo "target=$(slice_triple "$slice")"
    echo "sdk=$(basename "$sysroot") ($(xcrun --sdk "$(slice_sdk "$slice")" --show-sdk-version))"
    echo "clang=$("$CLANG" --version | sed -n 1p)"
    echo "built=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "profile=base static LGPL; libdav1d; libbluray+libudfread; VideoToolbox; network disabled"
    local c
    for c in ffmpeg dav1d libbluray libudfread; do
      echo "source.$c=$(lock_field "$c" version) sha256=$(lock_field "$c" sha256)"
    done
    echo "patchset.sha256=$(patch_set_digest)"
    echo "ffmpeg.configure=$line"
    echo "ffmpeg.environment=SDKROOT=$(basename "$sysroot"); clang and pkg-config on PATH; make install prefix=<stage>"
  } >"$tmp/BUILD-INFO.txt"
  # Verify before the slice becomes visible; swiftpm.env is written last so a
  # half-built slice is never linked by scripts/build_vision.sh.
  verify_slice "$slice" "$tmp"
  rm -rf "$final"; mv "$tmp" "$final"
  write_env "$slice"
  log "$slice ready: $final"
}

write_env() { # slice
  local slice="$1" prefix="$OUT/$1"
  cat >"$prefix/swiftpm.env" <<ENV
# Generated by scripts/build_ffmpeg_visionos.sh. scripts/build_vision.sh sources this
# (set -a) before xcodebuild; player-core's Package.swift reads these variables.
NSURATOR_PLAYER_CORE_FFMPEG_PREFIX=$prefix
NSURATOR_PLAYER_CORE_DEP_PREFIX=$prefix
NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE=base
NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE=static
NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES=libdav1d
NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS='$FFMPEG_EXTRA_FLAGS'
NSURATOR_PLAYER_CORE_ENABLE_NETWORK_PROTOCOLS=0
ENV
}

# ---------------------------------------------------------------- verification

LIBS="libavfilter libavformat libavcodec libavutil libswresample libswscale libbluray libdav1d"
FRAMEWORKS="-framework AVFoundation -framework CoreFoundation -framework CoreMedia -framework CoreVideo -framework AudioToolbox -framework VideoToolbox -lobjc -lz -lbz2 -liconv"

need_symbol() { # archive symbol
  nm -gU "$1" 2>/dev/null | grep -E " _$2\$" >/dev/null || die "$(basename "$1") does not define $2"
}

booted_visionos_simulator() {
  xcrun simctl list devices booted -j 2>/dev/null | python3 -c '
import json, sys
try:
    devices = json.load(sys.stdin)["devices"]
except Exception:
    devices = {}
print(next((d["udid"] for runtime, ds in devices.items() if "xrOS" in runtime or "visionOS" in runtime for d in ds), ""))
' || true
}

verify_slice() { # slice prefix
  local slice="$1" prefix="$2" sdk triple sysroot platform
  sdk="$(slice_sdk "$slice")"; triple="$(slice_triple "$slice")"; platform="$(slice_platform_id "$slice")"
  sysroot="$(xcrun --sdk "$sdk" --show-sdk-path)"
  log "verify $slice"
  local lib a info platforms
  for lib in $LIBS; do
    a="$prefix/lib/$lib.a"
    [[ -f "$a" ]] || die "missing $a"
    info="$(lipo -info "$a" 2>&1)"
    [[ "$info" == *"architecture: arm64" ]] || die "unexpected architectures in $lib.a: $info"
    platforms="$(otool -l "$a" | awk '/cmd LC_BUILD_VERSION/{f=1} f && $1=="platform"{print $2; f=0}' | sort -u | tr '\n' ' ')"
    [[ "$platforms" == "$platform " ]] || die "$lib.a LC_BUILD_VERSION platform is '$platforms', expected $platform"
    printf '  %-15s arm64, LC_BUILD_VERSION platform %s\n' "$lib.a" "$platform" >&2
  done
  for lib in libavcodec libavformat libavfilter libavutil libswresample libswscale; do
    [[ -d "$prefix/include/$lib" ]] || die "missing include/$lib"
  done
  [[ -f "$prefix/include/dav1d/dav1d.h" && -f "$prefix/include/libbluray/bluray.h" ]] || die "missing dav1d/libbluray headers"
  need_symbol "$prefix/lib/libavcodec.a" avcodec_send_packet
  need_symbol "$prefix/lib/libavcodec.a" ff_libdav1d_decoder
  need_symbol "$prefix/lib/libavformat.a" avformat_open_input
  need_symbol "$prefix/lib/libavfilter.a" avfilter_graph_alloc
  need_symbol "$prefix/lib/libdav1d.a" dav1d_open
  need_symbol "$prefix/lib/libdav1d.a" dav1d_send_data
  need_symbol "$prefix/lib/libbluray.a" bd_open
  need_symbol "$prefix/lib/libbluray.a" udfread_open
  nm -u "$prefix/lib/libavcodec.a" 2>/dev/null | grep '_dav1d_send_data$' >/dev/null || die "libavcodec.a does not reference dav1d"
  echo "  symbols: avcodec_send_packet, avformat_open_input, avfilter_graph_alloc, dav1d_open, bd_open, udfread_open present" >&2
  # The core's Matroska patches (V-D61): the demuxer's options the shim sets.
  local options
  options="$(strings -a "$prefix/lib/libavformat.a" \
    | LC_ALL=C grep -x -e cue_relative_seek -e cue_relative_seek_subtitle_margin -e skip_attachment_data \
    | LC_ALL=C sort -u | tr '\n' ' ' || true)"
  [[ "$options" == "cue_relative_seek cue_relative_seek_subtitle_margin skip_attachment_data " ]] \
    || die "libavformat.a lacks the Matroska options of the core's patches (found: '$options')"
  echo "  Matroska options: cue_relative_seek, cue_relative_seek_subtitle_margin, skip_attachment_data present" >&2

  # No library may name a directory of the Mac that built it (V-D57).
  local leaks="" found
  for lib in $LIBS; do
    found="$(strings -a "$prefix/lib/$lib.a" | LC_ALL=C grep -F -e /Users/ -e /Applications/ -e /Volumes/ -e /private/ -e "$WORK" -e "$ROOT" || true)"
    [[ -z "$found" ]] || { found="${found%%$'\n'*}"; leaks+="  $lib.a: ${found:0:160}"$'\n'; }
  done
  [[ -z "$leaks" ]] || { printf '%s' "$leaks" >&2; die "the $slice libraries name directories of the Mac that built them"; }
  echo "  paths: no /Users, /Applications, /Volumes, /private or work directory in the libraries" >&2

  # Probe program (scripts/ffmpeg/probe.c), linked the way player-core's
  # Package.swift links in static mode.
  local vdir="$WORK/verify/$slice"; rm -rf "$vdir"; mkdir -p "$vdir"
  local archives="" lib2
  for lib2 in $LIBS; do archives="$archives $prefix/lib/$lib2.a"; done
  "$CLANG" -target "$triple" -isysroot "$sysroot" -I"$prefix/include" -Wall -c "$FF_DIR/probe.c" -o "$vdir/probe.o" \
    || die "probe compile failed for $slice"
  # shellcheck disable=SC2086
  "$CLANG" -target "$triple" -isysroot "$sysroot" "$vdir/probe.o" $archives $FRAMEWORKS -o "$vdir/probe" \
    >"$vdir/link.log" 2>&1 || { cat "$vdir/link.log" >&2; die "probe link failed for $slice"; }
  [[ ! -s "$vdir/link.log" ]] || { cat "$vdir/link.log" >&2; die "probe link printed warnings for $slice"; }
  platforms="$(otool -l "$vdir/probe" | awk '/cmd LC_BUILD_VERSION/{f=1} f && $1=="platform"{print $2; f=0}')"
  [[ "$platforms" == "$platform" ]] || die "probe executable platform is $platforms, expected $platform"
  echo "  probe: compiled and linked for $triple without warnings (avformat_version, libdav1d, libbluray, VideoToolbox)" >&2
  if [[ "$slice" == xrsimulator-arm64 ]]; then
    local udid out
    udid="$(booted_visionos_simulator)"
    if [[ -n "$udid" ]]; then
      out="$(xcrun simctl spawn "$udid" "$vdir/probe" 2>&1)" \
        || { echo "$out" >&2; die "probe failed at runtime on the visionOS simulator"; }
      echo "  runtime on booted visionOS simulator: $out" >&2
    else
      echo "  runtime: skipped (no booted visionOS simulator; this script never boots one)" >&2
    fi
  fi

  # The player-core shim itself, compiled with the flags Package.swift adds for
  # this env and linked as an object (every reference must resolve).
  local shim="$PLAYER_CORE/Sources/NsuratorPlayerCoreFFmpegShim"
  if [[ -f "$shim/NsuratorPlayerCoreFFmpegShim.c" ]]; then
    $NICE "$CLANG" -target "$triple" -isysroot "$sysroot" -O0 \
      -DNPC_FFMPEG_CSHIM_ENABLE_LIBAV=1 -DNPC_FFMPEG_CSHIM_ENABLE_LIBBLURAY=1 \
      -I"$prefix/include" -I"$shim/include" -c "$shim/NsuratorPlayerCoreFFmpegShim.c" -o "$vdir/shim.o" \
      >"$vdir/shim-compile.log" 2>&1 || { tail -n 30 "$vdir/shim-compile.log" >&2; die "player-core shim does not compile against the $slice artifact"; }
    printf 'int main(void) { return 0; }\n' >"$vdir/main.c"
    # shellcheck disable=SC2086
    "$CLANG" -target "$triple" -isysroot "$sysroot" "$vdir/main.c" "$vdir/shim.o" $archives $FRAMEWORKS -o "$vdir/shim-probe" \
      >"$vdir/shim-link.log" 2>&1 || { tail -n 40 "$vdir/shim-link.log" >&2; die "player-core shim does not link against the $slice artifact"; }
    echo "  player-core shim ($(git --no-optional-locks -C "$PLAYER_CORE" rev-parse --short HEAD 2>/dev/null || echo '?')): compiles and links against the slice" >&2
  else
    log "player-core shim not found at $shim; skipped shim link check"
  fi
}

# ---------------------------------------------------------------- main

cmd="${1:-build}"
case "$cmd" in
  -h|--help|help) awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"; exit 0;;
  clean) rm -rf "$WORK"; log "removed $WORK"; exit 0;;
  build|verify) ;;
  *) die "unknown command: $cmd (build | verify | clean)";;
esac

check_tools
if [[ "$cmd" == verify ]]; then
  for slice in $SLICES; do
    [[ -f "$OUT/$slice/swiftpm.env" ]] || die "no artifact for $slice; run scripts/build_ffmpeg_visionos.sh build"
    verify_slice "$slice" "$OUT/$slice"
  done
  log "verified: $SLICES"
  exit 0
fi

for slice in $SLICES; do slice_sdk "$slice" >/dev/null; done
verify_archives
prepare_sources
for slice in $SLICES; do
  # A slice being rebuilt must not be linked half-way.
  rm -f "$OUT/$slice/swiftpm.env"
  build_slice "$slice"
done
log "done: $(for s in $SLICES; do printf '%s ' "$OUT/$s"; done)"
