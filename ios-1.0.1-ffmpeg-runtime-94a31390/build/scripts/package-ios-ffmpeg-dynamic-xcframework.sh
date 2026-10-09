#!/bin/zsh
set -euo pipefail

if (( $# > 3 )); then
  print -u2 "Usage: $0 [static.xcframework] [output.xcframework] [reviewed-lock.json]"
  exit 2
fi

project_root="${0:A:h:h}"
static_xcframework="${1:-$project_root/Packages/vision-player-core/Artifacts/VisionPlayerCoreFFmpegRuntime.static.xcframework}"
output_xcframework="${2:-$project_root/Packages/vision-player-core/Artifacts/VisionPlayerCoreFFmpegRuntime.xcframework}"
reviewed_lock="${3:-$project_root/scripts/ios-ffmpeg-runtime-lock.json}"
framework_name="VisionPlayerCoreFFmpegRuntime"
privacy_manifest="$project_root/Packages/vision-player-core/Artifacts/VisionPlayerCoreFFmpegRuntime.PrivacyInfo.xcprivacy"

if [[ ! -d "$static_xcframework" ]]; then
  print -u2 "Static input does not exist: $static_xcframework"
  exit 2
fi

if [[ ! -f "$privacy_manifest" ]]; then
  print -u2 "Privacy manifest does not exist: $privacy_manifest"
  exit 2
fi

if [[ ! -f "$reviewed_lock" ]]; then
  print -u2 "Reviewed runtime lock does not exist: $reviewed_lock"
  exit 2
fi

# Reject overlapping input/output and symlink destinations before any build or
# replacement. A typo must never remove the source archive or an unrelated tree.
python3 - "$static_xcframework" "$output_xcframework" "$reviewed_lock" <<'PY'
import json
from pathlib import Path
import sys
source, destination, lock = map(Path, sys.argv[1:])
if destination.is_symlink() or (destination.exists() and not destination.is_dir()):
    sys.exit("Output must be a directory path, not a symlink or file")
source, destination = source.resolve(), destination.resolve()
if destination.suffix != ".xcframework" or source == destination or source in destination.parents or destination in source.parents:
    sys.exit("Input and output must be separate, non-overlapping XCFramework paths")
with lock.open() as stream:
    data = json.load(stream)
if not isinstance(data, dict) or data.get("schema_version") != 1:
    sys.exit("Invalid reviewed lock schema")
PY

for slice in ios-arm64 ios-arm64-simulator; do
  for required in "lib$framework_name.a" "Headers/module.modulemap"; do
    if [[ ! -f "$static_xcframework/$slice/$required" ]]; then
      print -u2 "Static input is incomplete: $static_xcframework/$slice/$required"
      exit 2
    fi
  done
done

static_xcframework="${static_xcframework:A}"
output_xcframework="${output_xcframework:A}"
mkdir -p "${output_xcframework:h}"
lock_directory="$output_xcframework.packaging-lock"
if ! mkdir "$lock_directory"; then
  print -u2 "Another packager owns $lock_directory; inspect it before removing a stale lock."
  exit 2
fi
work_root=""
published=0
cleanup() {
  local result=$?
  local keep_work=0
  if [[ -n "$work_root" && -d "$work_root/previous.xcframework" && "$published" == 0 ]]; then
    # Includes interruption between the two renames. Never delete the old tree
    # until publication has completed, and retain it if recovery itself fails.
    if [[ -e "$output_xcframework" || -L "$output_xcframework" ]]; then
      mv "$output_xcframework" "$work_root/unpublished.xcframework" || keep_work=1
    fi
    if (( keep_work == 0 )); then
      mv "$work_root/previous.xcframework" "$output_xcframework" || keep_work=1
    fi
  fi
  if (( keep_work )); then
    print -u2 "Recovery needs attention; old runtime preserved at $work_root/previous.xcframework"
    result=1
  elif [[ -n "$work_root" ]]; then
    rm -rf "$work_root"
  fi
  rmdir "$lock_directory" || true
  return "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Stage on the destination filesystem so publication uses directory renames.
work_root="$(mktemp -d "${output_xcframework:h}/.nsurator-ffmpeg-package.XXXXXX")"

build_framework() {
  local slice="$1"
  local sdk="$2"
  local minimum_flag="$3"
  local source_root="$static_xcframework/$slice"
  local framework="$work_root/$slice/$framework_name.framework"

  # Explicit returns are necessary: zsh ERR_EXIT inside a function can bypass
  # an outer EXIT trap. The caller exits only after we return the failed status.
  mkdir -p "$framework/Headers" "$framework/Modules" || return $?
  ditto "$source_root/Headers" "$framework/Headers" || return $?
  cp "$source_root/Headers/module.modulemap" "$framework/Modules/module.modulemap" || return $?

  local sdk_path
  sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)" || return $?
  xcrun --sdk "$sdk" clang \
    -arch arm64 \
    -dynamiclib \
    -isysroot "$sdk_path" \
    "$minimum_flag" \
    -Wl,-force_load,"$source_root/lib$framework_name.a" \
    -Wl,-install_name,@rpath/$framework_name.framework/$framework_name \
    -Wl,-compatibility_version,1.0.0 \
    -Wl,-current_version,1.0.0 \
    -framework AVFoundation \
    -framework AudioToolbox \
    -framework CoreFoundation \
    -framework CoreMedia \
    -framework CoreVideo \
    -framework Security \
    -framework VideoToolbox \
    -lbz2 -liconv -lz -lc++ \
    -o "$framework/$framework_name" || return $?

  cat > "$framework/Info.plist" <<PLIST || return $?
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>$framework_name</string>
  <key>CFBundleIdentifier</key><string>com.nsurator.$framework_name</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>$framework_name</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>MinimumOSVersion</key><string>17.0</string>
</dict>
</plist>
PLIST
  cp "$privacy_manifest" "$framework/PrivacyInfo.xcprivacy" || return $?
}

build_framework "ios-arm64" "iphoneos" "-miphoneos-version-min=17.0" || exit $?
build_framework "ios-arm64-simulator" "iphonesimulator" "-mios-simulator-version-min=17.0" || exit $?

xcodebuild -create-xcframework \
  -framework "$work_root/ios-arm64/$framework_name.framework" \
  -framework "$work_root/ios-arm64-simulator/$framework_name.framework" \
  -output "$work_root/candidate.xcframework"

# This package is unsigned build input. Signing is verified on the final app;
# swallowing a codesign error here previously made a failed check look successful.
python3 "$project_root/scripts/audit-ios-ffmpeg-runtime.py" \
  "$work_root/candidate.xcframework" --lock "$reviewed_lock"

if [[ -d "$output_xcframework" ]]; then
  mv "$output_xcframework" "$work_root/previous.xcframework"
fi
mv "$work_root/candidate.xcframework" "$output_xcframework"
published=1
print "Published reviewed runtime: $output_xcframework"
