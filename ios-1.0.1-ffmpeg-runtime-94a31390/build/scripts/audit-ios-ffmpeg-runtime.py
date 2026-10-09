#!/usr/bin/env python3
"""Fail-closed audit of the reviewed iOS runtime; never treats configure as evidence."""

import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
NAME = "VisionPlayerCoreFFmpegRuntime"
DEFAULT_RUNTIME = ROOT / "Packages/vision-player-core/Artifacts" / f"{NAME}.xcframework"
DEFAULT_LOCK = Path(__file__).with_name("ios-ffmpeg-runtime-lock.json")
SLICES = {"ios-arm64": "IOS", "ios-arm64-simulator": "IOSSIMULATOR"}
REQUIRED_API_SYMBOLS = {
    "_avformat_open_input", "_avformat_find_stream_info", "_av_read_frame",
    "_avcodec_find_decoder", "_avcodec_send_packet", "_avcodec_receive_frame",
    "_av_frame_alloc", "_av_codec_iterate", "_av_demuxer_iterate",
    "_avio_enum_protocols", "_swr_convert", "_sws_scale", "_bd_open",
}
REQUIRED_HEADERS = (
    "libavformat/avformat.h", "libavcodec/avcodec.h", "libavutil/avutil.h",
    "libswresample/swresample.h", "libswscale/swscale.h", "libbluray/bluray.h",
)
OPTIONAL_EXPORT_PREFIXES = {
    "avfilter": "_avfilter_", "dav1d": "_dav1d_", "smb2": "_smb2_",
    "sftp_libssh": "_ssh_", "nfs": "_nfs_",
}


class AuditError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise AuditError(message)


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def contained_file(root, relative):
    relative_path = Path(relative)
    require(not relative_path.is_absolute() and ".." not in relative_path.parts,
            f"Unsafe relative path: {relative}")
    candidate = root / relative_path
    require(candidate.is_file(), f"Missing file: {candidate}")
    require(candidate.resolve().is_relative_to(root.resolve()), f"Path escapes bundle: {candidate}")
    require(not root.is_symlink() and not any(
        root.joinpath(*relative_path.parts[:depth]).is_symlink()
        for depth in range(1, len(relative_path.parts) + 1)),
            f"Symlinks are not accepted in reviewed runtime: {candidate}")
    return candidate


def tree_sha256(directory):
    require(directory.is_dir() and not directory.is_symlink(), f"Missing or symlink directory: {directory}")
    digest = hashlib.sha256()
    files = sorted(path for path in directory.rglob("*") if path.is_file() or path.is_symlink())
    require(bool(files), f"Empty directory: {directory}")
    for path in files:
        relative = path.relative_to(directory).as_posix()
        contained_file(directory, relative)
        digest.update(relative.encode("utf-8") + b"\0" + sha256(path).encode("ascii") + b"\n")
    return digest.hexdigest()


def read_plist(root, relative):
    try:
        result = plistlib.loads(contained_file(root, relative).read_bytes())
    except (ValueError, plistlib.InvalidFileException) as error:
        raise AuditError(f"Invalid plist: {root / relative}: {error}") from error
    require(isinstance(result, dict), f"Expected plist dictionary: {relative}")
    return result


def run_tool(arguments):
    try:
        completed = subprocess.run(["/usr/bin/xcrun", *arguments], check=True,
                                   capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError) as error:
        raise AuditError(f"Binary inspection failed ({arguments[0]}): {error}") from error
    return completed.stdout


def audit(runtime, lock_path, runner=run_tool):
    runtime = Path(runtime)
    require(runtime.is_dir() and not runtime.is_symlink(), f"Missing or symlink runtime: {runtime}")
    try:
        lock = json.loads(Path(lock_path).read_text())
    except (OSError, ValueError) as error:
        raise AuditError(f"Cannot read reviewed lock: {error}") from error
    require(isinstance(lock, dict) and lock.get("schema_version") == 1, "Unsupported lock schema")
    require(lock.get("framework_name") == NAME, "Unexpected framework name in lock")
    require(lock.get("minimum_os") == "17.0", "Reviewed deployment target must be iOS 17.0")
    require(set(lock.get("slices", {})) == set(SLICES), "Lock must cover both iOS arm64 slices")
    capabilities = lock.get("required_exported_capabilities", {})
    require(isinstance(capabilities, dict) and bool(capabilities), "Lock has no exported capability requirements")
    require(all(isinstance(value, list) and value and all(isinstance(s, str) and s.startswith("_") for s in value)
                for value in capabilities.values()), "Invalid capability symbol list")
    allowed_dependencies = set(lock.get("allowed_dependencies", []))
    install_name = f"@rpath/{NAME}.framework/{NAME}"
    require(bool(allowed_dependencies) and all(
        dependency.startswith("/System/Library/Frameworks/") or dependency.startswith("/usr/lib/")
        for dependency in allowed_dependencies), "Lock contains a non-system dependency")
    top = read_plist(runtime, "Info.plist")
    libraries = top.get("AvailableLibraries", [])
    require(isinstance(libraries, list) and len(libraries) == 2, "XCFramework must contain exactly two slices")
    require(all(isinstance(item, dict) for item in libraries), "Invalid XCFramework library entry")
    require({item.get("LibraryIdentifier") for item in libraries} == set(SLICES),
            "XCFramework is missing a required slice or contains an unexpected one")
    results = []
    for library in libraries:
        identifier = library["LibraryIdentifier"]
        expected = lock["slices"][identifier]
        require(library.get("SupportedPlatform") == "ios", f"{identifier}: plist platform is not iOS")
        variant = "simulator" if identifier.endswith("simulator") else None
        require(library.get("SupportedPlatformVariant") == variant, f"{identifier}: wrong platform variant")
        require(library.get("SupportedArchitectures") == ["arm64"], f"{identifier}: plist architecture is not arm64")
        framework_relative = f"{identifier}/{NAME}.framework"
        require(library.get("LibraryPath") == f"{NAME}.framework", f"{identifier}: unexpected framework path")
        require(library.get("BinaryPath", f"{NAME}.framework/{NAME}") == f"{NAME}.framework/{NAME}",
                f"{identifier}: unexpected binary path")
        binary = contained_file(runtime, f"{framework_relative}/{NAME}")
        framework = runtime / framework_relative
        info = read_plist(framework, "Info.plist")
        require(info.get("CFBundleExecutable") == NAME and info.get("CFBundlePackageType") == "FMWK",
                f"{identifier}: invalid framework metadata")
        require(info.get("MinimumOSVersion") == lock["minimum_os"], f"{identifier}: plist minOS mismatch")
        for header in REQUIRED_HEADERS:
            contained_file(framework, f"Headers/{header}")
        require(tree_sha256(framework / "Headers") == expected.get("headers_sha256"),
                f"{identifier}: headers hash differs from reviewed lock")
        module = contained_file(framework, "Modules/module.modulemap")
        require(sha256(module) == expected.get("modulemap_sha256"), f"{identifier}: module map hash mismatch")
        privacy = read_plist(framework, "PrivacyInfo.xcprivacy")
        require(privacy.get("NSPrivacyTracking") is False and privacy.get("NSPrivacyCollectedDataTypes") == [],
                f"{identifier}: unexpected tracking/data collection declaration")
        require(privacy.get("NSPrivacyAccessedAPITypes") == [{
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryFileTimestamp",
            "NSPrivacyAccessedAPITypeReasons": ["3B52.1", "C617.1"],
        }], f"{identifier}: required privacy reason is absent or changed")
        require(sha256(framework / "PrivacyInfo.xcprivacy") == expected.get("privacy_sha256"),
                f"{identifier}: privacy manifest hash mismatch")
        actual_hash = sha256(binary)
        require(actual_hash == expected.get("binary_sha256"), f"{identifier}: binary SHA-256 differs from reviewed lock")
        architectures = runner(["lipo", "-archs", str(binary)]).split()
        require(architectures == ["arm64"], f"{identifier}: Mach-O architecture mismatch: {architectures}")
        build = runner(["vtool", "-show-build", str(binary)])
        platforms = re.findall(r"^\s*platform\s+(\S+)\s*$", build, re.MULTILINE)
        minimums = re.findall(r"^\s*minos\s+(\S+)\s*$", build, re.MULTILINE)
        require(platforms == [SLICES[identifier]], f"{identifier}: actual Mach-O platform mismatch: {platforms}")
        require(minimums == [lock["minimum_os"]], f"{identifier}: actual Mach-O minOS mismatch: {minimums}")
        ids = runner(["otool", "-D", str(binary)]).splitlines()[1:]
        require([value.strip() for value in ids if value.strip()] == [install_name],
                f"{identifier}: install name mismatch")
        dependency_lines = runner(["otool", "-L", str(binary)]).splitlines()[1:]
        dependencies = [value.strip().split(" (", 1)[0] for value in dependency_lines if value.strip()]
        require(dependencies.count(install_name) == 1, f"{identifier}: missing dylib identity")
        external = set(dependencies) - {install_name}
        require(external == allowed_dependencies,
                f"{identifier}: dependency mismatch; unexpected={sorted(external - allowed_dependencies)}, "
                f"missing={sorted(allowed_dependencies - external)}")
        exports_output = runner(["dyld_info", "-exports", str(binary)])
        exports = set(re.findall(r"^\s*0x[0-9a-fA-F]+\s+(_\S+)\s*$", exports_output, re.MULTILINE))
        required = REQUIRED_API_SYMBOLS | {symbol for group in capabilities.values() for symbol in group}
        require(required <= exports, f"{identifier}: required exported symbols missing: {sorted(required - exports)}")
        results.append({
            "slice": identifier, "architecture": "arm64", "platform": platforms[0],
            "minimum_os": minimums[0], "binary_sha256": actual_hash,
            "exported_capabilities": sorted(capabilities),
            "optional_api_exports": {name: any(symbol.startswith(prefix) for symbol in exports)
                                     for name, prefix in OPTIONAL_EXPORT_PREFIXES.items()},
        })
    return {"status": "passed", "runtime": str(runtime), "slices": results,
            "evidence_limit": "Exported APIs and implementation descriptors prove binary presence only. "
                              "Codec/profile playback, hardware support and registration require runtime tests."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runtime", nargs="?", type=Path, default=DEFAULT_RUNTIME)
    parser.add_argument("--lock", type=Path, default=DEFAULT_LOCK)
    arguments = parser.parse_args()
    try:
        result = audit(arguments.runtime, arguments.lock)
    except (AuditError, OSError, KeyError, TypeError, ValueError) as error:
        print(f"FFmpeg runtime audit FAILED: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
