#!/usr/bin/env bash
# Packages a built FFmpeg/libbluray/dav1d install as one dynamic framework, so
# an app links the LGPL libraries dynamically and a user can replace them.
#
# Every static archive under the FFmpeg prefix and the dependency prefix is
# force-loaded, one by one and unchanged, into a single image. Splitting the
# libraries into several dylibs is not an option: a static FFmpeg build is one
# linkage unit (the libraries reference each other's internal ff_* symbols).
# The iPhone app ships the same single-image shape.
set -euo pipefail

framework_name="NsuratorPlayerCoreFFmpegRuntime"
framework_version="A"
install_name="@rpath/${framework_name}.framework/Versions/${framework_version}/${framework_name}"
# iPhone and iPad frameworks are shallow bundles: binary, Info.plist and
# privacy manifest at the top, no Versions directory.
shallow_install_name="@rpath/${framework_name}.framework/${framework_name}"
bundle_identifier="com.haoyu.nsurator.${framework_name}"

# The exports the app and the decoder helper resolve through the framework;
# a framework without one of them cannot serve the player.
required_exports=(
  _avformat_open_input
  _avcodec_send_packet
  _av_codec_iterate
  _av_demuxer_iterate
  _avfilter_graph_alloc
  _swr_alloc
  _sws_getContext
  _bd_open
  _bd_select_hdmv_menu_button
  _dav1d_open
  _ff_libdav1d_decoder
  _ff_check_interrupt
)

usage() {
  cat <<'USAGE'
Usage:
  scripts/package-apple-ffmpeg-runtime-framework.sh --build \
      --ffmpeg-prefix <dir> [--dependency-prefix <dir>] --output-dir <dir> \
      [--sdk macosx|iphoneos|iphonesimulator] [--target-triple arm64-apple-macos14.0] \
      [--short-version <x.y.z>] [--record-root <dir>]
  scripts/package-apple-ffmpeg-runtime-framework.sh --verify <framework> [--minimum-os <x.y>]
  scripts/package-apple-ffmpeg-runtime-framework.sh --print-install-name [macosx|iphoneos|iphonesimulator]

--build links every lib*.a under <ffmpeg-prefix>/lib and <dependency-prefix>/lib
with -force_load into <output-dir>/NsuratorPlayerCoreFFmpegRuntime.framework
(no headers) and writes <output-dir>/FRAMEWORK-RECORD.json. macosx builds the
versioned macOS layout; iphoneos (target arm64-apple-ios17.0) and
iphonesimulator (arm64-apple-ios17.0-simulator) build the shallow iOS layout,
one slice each, which an app joins into an XCFramework with
xcodebuild -create-xcframework.
Paths in the record are relative to --record-root (default: the parent of
<output-dir>'s parent) so the record carries no machine paths.

--verify checks the layout, install name, architecture, minimum OS, that every
dependency is a system library, that no embedded bitcode survived, and that the
player's required symbols are exported.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 66
}

sha256_of() {
  /usr/bin/shasum -a 256 "$1" | /usr/bin/awk '{print $1}'
}

macho_uuid() {
  /usr/bin/otool -l "$1" | /usr/bin/awk '/cmd LC_UUID/{inside=1} inside && $1 == "uuid" {print $2; exit}'
}

build_version_field() {
  local binary="$1" field="$2"
  /usr/bin/otool -l "$binary" | /usr/bin/awk -v field="$field" '/cmd LC_BUILD_VERSION/{inside=1} inside && $1 == field {print $2; exit}'
}

relative_to() {
  local path="$1" root="$2"
  case "$path" in
    "$root"/*) printf '%s' "${path#"$root"/}" ;;
    *) printf '%s' "$(basename "$path")" ;;
  esac
}

ordered_archives() {
  local ffmpeg_lib="$1" dependency_lib="$2"
  local name
  # FFmpeg's own libraries first, in dependency order, then every other
  # archive in each prefix by name. The order is fixed so the image is too.
  for name in libavfilter libavformat libavcodec libswresample libswscale libavutil; do
    [[ -f "${ffmpeg_lib}/${name}.a" ]] || die "missing FFmpeg archive: ${ffmpeg_lib}/${name}.a"
    printf '%s\n' "${ffmpeg_lib}/${name}.a"
  done
  local archive
  while IFS= read -r archive; do
    case "$(basename "$archive" .a)" in
      libavfilter|libavformat|libavcodec|libswresample|libswscale|libavutil) ;;
      *) printf '%s\n' "$archive" ;;
    esac
  done < <(/usr/bin/find "$ffmpeg_lib" -maxdepth 1 -type f -name 'lib*.a' | LC_ALL=C /usr/bin/sort)
  if [[ -n "$dependency_lib" && "$dependency_lib" != "$ffmpeg_lib" ]]; then
    /usr/bin/find "$dependency_lib" -maxdepth 1 -type f -name 'lib*.a' | LC_ALL=C /usr/bin/sort
  fi
}

# System frameworks and libraries the archives need, from their pkg-config
# files: -framework pairs and -l of libraries that are not among the archives.
system_link_flags() {
  local ffmpeg_prefix="$1" dependency_prefix="$2"
  shift 2
  local archive_names=" "
  local archive
  for archive in "$@"; do
    local stem
    stem="$(basename "$archive" .a)"
    archive_names="${archive_names}${stem#lib} "
  done

  local pkg_config="${NSURATOR_PLAYER_CORE_PKG_CONFIG:-}"
  if [[ -z "$pkg_config" ]]; then
    pkg_config="$(command -v pkg-config || true)"
  fi
  [[ -n "$pkg_config" && -x "$pkg_config" ]] || die "pkg-config is required to read the archives' system dependencies"

  local pkg_config_libdir="${ffmpeg_prefix}/lib/pkgconfig"
  if [[ -n "$dependency_prefix" ]]; then
    pkg_config_libdir="${pkg_config_libdir}:${dependency_prefix}/lib/pkgconfig"
  fi
  local packages=()
  local pc
  while IFS= read -r pc; do
    packages+=("$(basename "$pc" .pc)")
  done < <(
    /usr/bin/find "${ffmpeg_prefix}/lib/pkgconfig" ${dependency_prefix:+"${dependency_prefix}/lib/pkgconfig"} \
      -maxdepth 1 -type f -name '*.pc' 2>/dev/null | LC_ALL=C /usr/bin/sort
  )
  [[ ${#packages[@]} -gt 0 ]] || die "no pkg-config files under ${ffmpeg_prefix}/lib/pkgconfig"

  local words
  words="$(PKG_CONFIG_LIBDIR="$pkg_config_libdir" PKG_CONFIG_PATH="" "$pkg_config" --static --libs "${packages[@]}")" \
    || die "pkg-config could not resolve ${packages[*]}"

  local -a tokens
  read -r -a tokens <<< "$words"
  local emitted=" "
  local index=0
  while (( index < ${#tokens[@]} )); do
    local token="${tokens[$index]}"
    case "$token" in
      -framework)
        index=$((index + 1))
        local framework="${tokens[$index]:-}"
        if [[ -n "$framework" && "$emitted" != *" -framework:${framework} "* ]]; then
          emitted="${emitted}-framework:${framework} "
          printf '%s\n%s\n' "-framework" "$framework"
        fi
        ;;
      -pthread)
        ;;
      -l*)
        local library="${token#-l}"
        if [[ "$archive_names" != *" ${library} "* && "$emitted" != *" ${token} "* ]]; then
          emitted="${emitted}${token} "
          printf '%s\n' "$token"
        fi
        ;;
    esac
    index=$((index + 1))
  done
}

write_info_plist() {
  local path="$1" short_version="$2" minimum_os="$3" sdk="${4:-macosx}"
  local supported_platform="MacOSX" minimum_key="LSMinimumSystemVersion"
  case "$sdk" in
    iphoneos) supported_platform="iPhoneOS"; minimum_key="MinimumOSVersion" ;;
    iphonesimulator) supported_platform="iPhoneSimulator"; minimum_key="MinimumOSVersion" ;;
  esac
  cat > "$path" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>${framework_name}</string>
	<key>CFBundleIdentifier</key>
	<string>${bundle_identifier}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>${framework_name}</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>${short_version}</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>${supported_platform}</string>
	</array>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>${minimum_key}</key>
	<string>${minimum_os}</string>
</dict>
</plist>
PLIST
}

# The same declaration as the iPhone runtime framework: FFmpeg and libbluray
# read file timestamps (stat) on files the user opened.
write_privacy_manifest() {
  cat > "$1" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>3B52.1</string>
				<string>C617.1</string>
			</array>
		</dict>
	</array>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyTracking</key>
	<false/>
</dict>
</plist>
PLIST
}

minimum_os_from_triple() {
  local triple="${1%-simulator}"
  local version
  case "$triple" in
    *-macos*) version="${triple##*-macos}" ;;
    *-ios*) version="${triple##*-ios}" ;;
    *) version="" ;;
  esac
  [[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]] \
    || die "target triple must be <arch>-apple-macos<version> or <arch>-apple-ios<version>[-simulator]: ${1}"
  printf '%s' "$version"
}

verify_framework() {
  local framework="$1" minimum_os="$2"
  framework="${framework%/}"
  [[ -d "$framework" && ! -L "$framework" ]] || die "framework is missing: ${framework}"
  [[ "$(basename "$framework")" == "${framework_name}.framework" ]] || die "framework must be named ${framework_name}.framework"
  if [[ ! -e "${framework}/Versions" ]]; then
    verify_shallow_framework "$framework" "$minimum_os"
    return
  fi
  local versions="${framework}/Versions"
  local binary="${versions}/${framework_version}/${framework_name}"
  [[ -f "$binary" && ! -L "$binary" ]] || die "framework binary is missing: ${binary}"
  [[ -L "${versions}/Current" && "$(/usr/bin/readlink "${versions}/Current")" == "$framework_version" ]] \
    || die "Versions/Current must be a symlink to ${framework_version}"
  [[ -L "${framework}/${framework_name}" && "$(/usr/bin/readlink "${framework}/${framework_name}")" == "Versions/Current/${framework_name}" ]] \
    || die "${framework_name} must be a symlink to Versions/Current/${framework_name}"
  [[ -L "${framework}/Resources" && "$(/usr/bin/readlink "${framework}/Resources")" == "Versions/Current/Resources" ]] \
    || die "Resources must be a symlink to Versions/Current/Resources"
  [[ ! -e "${framework}/Headers" && ! -e "${versions}/${framework_version}/Headers" ]] \
    || die "the runtime framework must not carry headers"
  local info_plist="${versions}/${framework_version}/Resources/Info.plist"
  [[ -f "$info_plist" ]] || die "framework Info.plist is missing"
  [[ "$(/usr/bin/plutil -extract CFBundlePackageType raw -o - "$info_plist")" == "FMWK" ]] || die "framework Info.plist is not FMWK"
  [[ "$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "$info_plist")" == "$framework_name" ]] || die "framework CFBundleExecutable is wrong"
  [[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$info_plist")" == "$bundle_identifier" ]] || die "framework CFBundleIdentifier is wrong"
  [[ -f "${versions}/${framework_version}/Resources/PrivacyInfo.xcprivacy" ]] || die "framework privacy manifest is missing"
  /usr/bin/plutil -lint "${versions}/${framework_version}/Resources/PrivacyInfo.xcprivacy" >/dev/null || die "framework privacy manifest is invalid"

  local recorded_install_name
  recorded_install_name="$(/usr/bin/otool -D "$binary" | /usr/bin/sed -n '2p')"
  [[ "$recorded_install_name" == "$install_name" ]] || die "install name is ${recorded_install_name:-missing}, expected ${install_name}"
  [[ "$(/usr/bin/lipo -archs "$binary")" == "arm64" ]] || die "framework must be arm64-only"
  local recorded_minimum
  recorded_minimum="$(build_version_field "$binary" minos)"
  [[ "$recorded_minimum" == "$minimum_os" ]] || die "framework minimum OS is ${recorded_minimum:-missing}, expected ${minimum_os}"
  [[ "$(build_version_field "$binary" platform)" == "1" ]] || die "framework is not built for macOS"
  verify_binary_contents "$binary"
  echo "Verified runtime framework: ${framework}"
}

# The checks every layout shares: system dependencies only, no bitcode, and the
# exports the player resolves.
verify_binary_contents() {
  local binary="$1"
  local dependency
  while IFS= read -r dependency; do
    case "$dependency" in
      /System/Library/*|/usr/lib/*) ;;
      *) die "framework has a non-system dependency: ${dependency}" ;;
    esac
  done < <(/usr/bin/otool -L "$binary" | /usr/bin/sed '1,2d' | /usr/bin/awk '{print $1}')
  if /usr/bin/otool -l "$binary" | /usr/bin/grep -Eq 'segname __LLVM|sectname __bitcode'; then
    die "framework still carries embedded bitcode"
  fi
  local exports
  exports="$(/usr/bin/nm -gU "$binary")"
  local symbol
  for symbol in "${required_exports[@]}"; do
    /usr/bin/grep -q " ${symbol}$" <<<"$exports" || die "framework does not export ${symbol}"
  done
}

# iPhone and iPad (device or simulator), from CFBundleSupportedPlatforms.
verify_shallow_framework() {
  local framework="$1" minimum_os="$2"
  local binary="${framework}/${framework_name}"
  [[ -f "$binary" && ! -L "$binary" ]] || die "framework binary is missing: ${binary}"
  [[ ! -e "${framework}/Headers" ]] || die "the runtime framework must not carry headers"
  local entry
  while IFS= read -r entry; do
    [[ ! -L "$entry" ]] || die "the iOS runtime framework must not contain symbolic links: ${entry}"
  done < <(/usr/bin/find "$framework" -mindepth 1)
  local info_plist="${framework}/Info.plist"
  [[ -f "$info_plist" ]] || die "framework Info.plist is missing"
  [[ "$(/usr/bin/plutil -extract CFBundlePackageType raw -o - "$info_plist")" == "FMWK" ]] || die "framework Info.plist is not FMWK"
  [[ "$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "$info_plist")" == "$framework_name" ]] || die "framework CFBundleExecutable is wrong"
  [[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "$info_plist")" == "$bundle_identifier" ]] || die "framework CFBundleIdentifier is wrong"
  [[ "$(/usr/bin/plutil -extract MinimumOSVersion raw -o - "$info_plist")" == "$minimum_os" ]] || die "framework MinimumOSVersion is not ${minimum_os}"
  local supported_platform expected_platform
  supported_platform="$(/usr/bin/plutil -extract CFBundleSupportedPlatforms.0 raw -o - "$info_plist")"
  case "$supported_platform" in
    iPhoneOS) expected_platform="2" ;;
    iPhoneSimulator) expected_platform="7" ;;
    *) die "framework CFBundleSupportedPlatforms is ${supported_platform:-missing}, expected iPhoneOS or iPhoneSimulator" ;;
  esac
  [[ -f "${framework}/PrivacyInfo.xcprivacy" ]] || die "framework privacy manifest is missing"
  /usr/bin/plutil -lint "${framework}/PrivacyInfo.xcprivacy" >/dev/null || die "framework privacy manifest is invalid"

  local recorded_install_name
  recorded_install_name="$(/usr/bin/otool -D "$binary" | /usr/bin/sed -n '2p')"
  [[ "$recorded_install_name" == "$shallow_install_name" ]] \
    || die "install name is ${recorded_install_name:-missing}, expected ${shallow_install_name}"
  [[ "$(/usr/bin/lipo -archs "$binary")" == "arm64" ]] || die "framework must be arm64-only"
  local recorded_minimum
  recorded_minimum="$(build_version_field "$binary" minos)"
  [[ "$recorded_minimum" == "$minimum_os" ]] || die "framework minimum OS is ${recorded_minimum:-missing}, expected ${minimum_os}"
  [[ "$(build_version_field "$binary" platform)" == "$expected_platform" ]] \
    || die "framework binary is not built for ${supported_platform}"
  verify_binary_contents "$binary"
  echo "Verified runtime framework: ${framework}"
}

build_framework() {
  local ffmpeg_prefix="" dependency_prefix="" output_dir="" sdk="macosx"
  local target_triple="arm64-apple-macos14.0" short_version="" record_root=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ffmpeg-prefix) ffmpeg_prefix="${2:-}"; shift 2 ;;
      --dependency-prefix) dependency_prefix="${2:-}"; shift 2 ;;
      --output-dir) output_dir="${2:-}"; shift 2 ;;
      --sdk) sdk="${2:-}"; shift 2 ;;
      --target-triple) target_triple="${2:-}"; shift 2 ;;
      --short-version) short_version="${2:-}"; shift 2 ;;
      --record-root) record_root="${2:-}"; shift 2 ;;
      *) usage >&2; exit 64 ;;
    esac
  done
  [[ -n "$ffmpeg_prefix" && -n "$output_dir" ]] || { usage >&2; exit 64; }
  case "$sdk" in
    macosx)
      [[ "$target_triple" == arm64-apple-macos* ]] || die "a macosx framework needs an arm64-apple-macos target: ${target_triple}" ;;
    iphoneos)
      [[ "$target_triple" == arm64-apple-ios* && "$target_triple" != *-simulator ]] \
        || die "an iphoneos framework needs an arm64-apple-ios target: ${target_triple}" ;;
    iphonesimulator)
      [[ "$target_triple" == arm64-apple-ios*-simulator ]] \
        || die "an iphonesimulator framework needs an arm64-apple-ios<version>-simulator target: ${target_triple}" ;;
    *) die "the runtime framework is built for macosx, iphoneos or iphonesimulator, not ${sdk}" ;;
  esac
  local shallow=0 framework_install_name="$install_name"
  if [[ "$sdk" != "macosx" ]]; then
    shallow=1
    framework_install_name="$shallow_install_name"
  fi
  [[ -d "${ffmpeg_prefix}/lib" ]] || die "FFmpeg prefix has no lib directory: ${ffmpeg_prefix}"
  ffmpeg_prefix="$(cd "$ffmpeg_prefix" && pwd -P)"
  if [[ -n "$dependency_prefix" ]]; then
    [[ -d "${dependency_prefix}/lib" ]] || die "dependency prefix has no lib directory: ${dependency_prefix}"
    dependency_prefix="$(cd "$dependency_prefix" && pwd -P)"
  fi
  mkdir -p "$output_dir"
  output_dir="$(cd "$output_dir" && pwd -P)"
  if [[ -z "$record_root" ]]; then
    record_root="$(dirname "$(dirname "$output_dir")")"
  fi
  record_root="$(cd "$record_root" && pwd -P)"
  local minimum_os
  minimum_os="$(minimum_os_from_triple "$target_triple")"
  if [[ -z "$short_version" ]]; then
    short_version="$(/usr/bin/sed -n 's/^#define FFMPEG_VERSION "\([0-9.]*\).*/\1/p' "${ffmpeg_prefix}/include/libavutil/ffversion.h" 2>/dev/null || true)"
    [[ -n "$short_version" ]] || short_version="1.0.0"
  fi

  local archives=()
  local archive
  while IFS= read -r archive; do
    archives+=("$archive")
  done < <(ordered_archives "${ffmpeg_prefix}/lib" "${dependency_prefix:+${dependency_prefix}/lib}")
  [[ ${#archives[@]} -gt 0 ]] || die "no static archives to package"

  local system_flags=()
  local flag
  while IFS= read -r flag; do
    system_flags+=("$flag")
  done < <(system_link_flags "$ffmpeg_prefix" "$dependency_prefix" "${archives[@]}")

  local framework="${output_dir}/${framework_name}.framework"
  stage_dir="$(/usr/bin/mktemp -d "${output_dir}/.${framework_name}.stage.XXXXXX")"
  local staged="${stage_dir}/${framework_name}.framework"
  local staged_version="${staged}/Versions/${framework_version}"
  local staged_binary="${staged_version}/${framework_name}"
  local recorded_binary="${framework_name}.framework/Versions/${framework_version}/${framework_name}"
  if [[ "$shallow" == "1" ]]; then
    staged_version="$staged"
    staged_binary="${staged}/${framework_name}"
    recorded_binary="${framework_name}.framework/${framework_name}"
    mkdir -p "$staged"
  else
    mkdir -p "${staged_version}/Resources"
  fi

  local sdk_path
  sdk_path="$(/usr/bin/xcrun --sdk "$sdk" --show-sdk-path)"
  local link_command=(
    /usr/bin/xcrun --sdk "$sdk" clang
    -target "$target_triple"
    -isysroot "$sdk_path"
    -dynamiclib
  )
  for archive in "${archives[@]}"; do
    link_command+=("-Wl,-force_load,${archive}")
  done
  link_command+=(
    "-Wl,-install_name,${framework_install_name}"
    -Wl,-compatibility_version,1.0.0
    -Wl,-current_version,1.0.0
    -Wl,-headerpad_max_install_names
    "${system_flags[@]}"
    -o "$staged_binary"
  )
  "${link_command[@]}"

  if [[ "$shallow" == "1" ]]; then
    write_info_plist "${staged}/Info.plist" "$short_version" "$minimum_os" "$sdk"
    write_privacy_manifest "${staged}/PrivacyInfo.xcprivacy"
  else
    write_info_plist "${staged_version}/Resources/Info.plist" "$short_version" "$minimum_os" "$sdk"
    write_privacy_manifest "${staged_version}/Resources/PrivacyInfo.xcprivacy"
    /bin/ln -s "$framework_version" "${staged}/Versions/Current"
    /bin/ln -s "Versions/Current/${framework_name}" "${staged}/${framework_name}"
    /bin/ln -s "Versions/Current/Resources" "${staged}/Resources"
  fi
  verify_framework "$staged" "$minimum_os" >/dev/null

  /bin/rm -rf "$framework"
  /bin/mv "$staged" "$framework"
  /bin/rm -rf "$stage_dir"
  stage_dir=""

  local binary="${framework}/${recorded_binary#"${framework_name}.framework/"}"
  local record="${output_dir}/FRAMEWORK-RECORD.json"
  local recorded_command=()
  local word
  for word in "${link_command[@]}"; do
    case "$word" in
      "$sdk_path") recorded_command+=("\$(xcrun --sdk ${sdk} --show-sdk-path)") ;;
      -Wl,-force_load,*) recorded_command+=("-Wl,-force_load,$(relative_to "${word#-Wl,-force_load,}" "$record_root")") ;;
      "$staged_binary") recorded_command+=("$recorded_binary") ;;
      *) recorded_command+=("$word") ;;
    esac
  done
  local inputs_file="${output_dir}/.${framework_name}.inputs.tsv"
  : > "$inputs_file"
  for archive in "${archives[@]}"; do
    printf '%s\t%s\n' "$(relative_to "$archive" "$record_root")" "$(sha256_of "$archive")" >> "$inputs_file"
  done
  local export_list_sha exported_count
  export_list_sha="$(/usr/bin/nm -gU "$binary" | /usr/bin/awk '{print $NF}' | LC_ALL=C /usr/bin/sort | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')"
  exported_count="$(/usr/bin/nm -gU "$binary" | /usr/bin/wc -l | /usr/bin/tr -d ' ')"

  NPC_RECORD_PATH="$record" \
  NPC_RECORD_INPUTS="$inputs_file" \
  NPC_RECORD_NAME="$framework_name" \
  NPC_RECORD_INSTALL_NAME="$framework_install_name" \
  NPC_RECORD_SDK_NAME="$sdk" \
  NPC_RECORD_BUNDLE_IDENTIFIER="$bundle_identifier" \
  NPC_RECORD_SHORT_VERSION="$short_version" \
  NPC_RECORD_MINIMUM_OS="$minimum_os" \
  NPC_RECORD_SDK="$(build_version_field "$binary" sdk)" \
  NPC_RECORD_BINARY_SHA256="$(sha256_of "$binary")" \
  NPC_RECORD_UUID="$(macho_uuid "$binary")" \
  NPC_RECORD_EXPORT_LIST_SHA256="$export_list_sha" \
  NPC_RECORD_EXPORT_COUNT="$exported_count" \
  NPC_RECORD_CLANG="$(/usr/bin/xcrun --sdk "$sdk" clang --version | /usr/bin/head -n 1)" \
  NPC_RECORD_LD="$(/usr/bin/xcrun --sdk "$sdk" ld -v 2>&1 | /usr/bin/head -n 1)" \
    python3 -I -c '
import json, os, sys
env = os.environ
inputs = []
with open(env["NPC_RECORD_INPUTS"], encoding="utf-8") as handle:
    for row in handle.read().splitlines():
        if row:
            path, digest = row.split("\t")
            inputs.append({"relativePath": path, "sha256": digest})
record = {
    "schemaVersion": 1,
    "name": env["NPC_RECORD_NAME"],
    "relativePath": env["NPC_RECORD_NAME"] + ".framework",
    "sdk": env["NPC_RECORD_SDK_NAME"],
    "installName": env["NPC_RECORD_INSTALL_NAME"],
    "bundleIdentifier": env["NPC_RECORD_BUNDLE_IDENTIFIER"],
    "shortVersion": env["NPC_RECORD_SHORT_VERSION"],
    "architecture": "arm64",
    "minimumOSVersion": env["NPC_RECORD_MINIMUM_OS"],
    "linkedSDKVersion": env["NPC_RECORD_SDK"],
    "binarySHA256": env["NPC_RECORD_BINARY_SHA256"],
    "uuid": env["NPC_RECORD_UUID"],
    "exportListSHA256": env["NPC_RECORD_EXPORT_LIST_SHA256"],
    "exportedSymbolCount": int(env["NPC_RECORD_EXPORT_COUNT"]),
    "staticInputs": inputs,
    "linkCommand": sys.argv[1:],
    "toolchain": {"clang": env["NPC_RECORD_CLANG"], "ld": env["NPC_RECORD_LD"]},
}
with open(env["NPC_RECORD_PATH"], "w", encoding="utf-8") as handle:
    json.dump(record, handle, indent=2, sort_keys=True)
    handle.write("\n")
' "${recorded_command[@]}"
  /bin/rm -f "$inputs_file"
  echo "Packaged runtime framework: ${framework}"
}

stage_dir=""
cleanup_stage() {
  if [[ -n "$stage_dir" && -d "$stage_dir" ]]; then
    /bin/rm -rf "$stage_dir"
  fi
}
trap cleanup_stage EXIT

main() {
  case "${1:-}" in
    --build)
      shift
      build_framework "$@"
      ;;
    --verify)
      local framework="${2:-}"
      [[ -n "$framework" ]] || { usage >&2; exit 64; }
      local minimum_os="14.0"
      if [[ "${3:-}" == "--minimum-os" ]]; then
        minimum_os="${4:-}"
      fi
      verify_framework "$framework" "$minimum_os"
      ;;
    --print-install-name)
      case "${2:-macosx}" in
        iphoneos|iphonesimulator) printf '%s\n' "$shallow_install_name" ;;
        *) printf '%s\n' "$install_name" ;;
      esac
      ;;
    --help|-h)
      usage
      ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
}

main "$@"
