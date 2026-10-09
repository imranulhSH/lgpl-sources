#!/usr/bin/env python3
"""Build an isolated, explicitly unapproved candidate from pinned-source installs.

This records hashes for review, then runs all structural/capability audits. It
never updates the checked-in runtime or reviewed lock. Run integration tests
and review source/config/license changes before using the production packager.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import plistlib
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent
NAME = "VisionPlayerCoreFFmpegRuntime"
CORE = ROOT / "Packages/vision-player-core"


def run(*arguments):
    subprocess.run(list(map(str, arguments)), check=True)


def stage(install, output):
    install, output = install.resolve(), output.resolve()
    if output.exists() or output == ROOT or ROOT in output.parents:
        raise ValueError("Candidate output must be a new directory outside the repository")
    archives = ["avformat", "avcodec", "avutil", "swresample", "swscale"]
    slices = [("ios-arm64", "iphoneos-arm64", "iphoneos", "-miphoneos-version-min=17.0"),
              ("ios-arm64-simulator", "iphonesimulator-arm64", "iphonesimulator", "-mios-simulator-version-min=17.0")]
    for _, source, _, _ in slices:
        for path in [*(install / "ffmpeg" / source / "lib" / f"lib{name}.a" for name in archives),
                     install / "dependencies" / source / "lib/libbluray.a",
                     install / "dependencies" / source / "lib/libdav1d.a"]:
            if not path.is_file() or path.is_symlink():
                raise ValueError(f"Missing or symlink source archive: {path}")
    output.mkdir(parents=True)
    static = output / f"{NAME}.static.xcframework"
    frameworks = []
    for identifier, source, sdk, minimum in slices:
        prefix, dependency = install / "ffmpeg" / source, install / "dependencies" / source
        merged = static / identifier / f"lib{NAME}.a"
        merged.parent.mkdir(parents=True)
        run("xcrun", "libtool", "-static", "-o", merged,
            *(prefix / "lib" / f"lib{name}.a" for name in archives), dependency / "lib/libbluray.a", dependency / "lib/libdav1d.a")
        headers = merged.parent / "Headers"
        shutil.copytree(prefix / "include", headers)
        shutil.copytree(dependency / "include/libbluray", headers / "libbluray")
        shutil.copytree(dependency / "include/dav1d", headers / "dav1d")
        (headers / f"{NAME}.h").write_text("#pragma once\n\n/* Pinned Apple FFmpeg runtime; use individual libav headers. */\n")
        (headers / "module.modulemap").write_text(f'module {NAME} {{\n    header "{NAME}.h"\n    export *\n}}\n')
        framework = output / identifier / f"{NAME}.framework"
        shutil.copytree(headers, framework / "Headers")
        (framework / "Modules").mkdir()
        shutil.copy2(headers / "module.modulemap", framework / "Modules/module.modulemap")
        sysroot = subprocess.check_output(["xcrun", "--sdk", sdk, "--show-sdk-path"], text=True).strip()
        command = ["xcrun", "--sdk", sdk, "clang", "-arch", "arm64", "-dynamiclib", "-isysroot", sysroot, minimum,
                   f"-Wl,-force_load,{merged}", f"-Wl,-install_name,@rpath/{NAME}.framework/{NAME}",
                   "-Wl,-compatibility_version,1.0.0", "-Wl,-current_version,1.0.0"]
        for name in ["AVFoundation", "AudioToolbox", "CoreFoundation", "CoreMedia", "CoreVideo", "Security", "VideoToolbox"]:
            command += ["-framework", name]
        run(*command, "-lbz2", "-liconv", "-lz", "-lc++", "-o", framework / NAME)
        info = dict(CFBundleDevelopmentRegion="en", CFBundleExecutable=NAME,
                    CFBundleIdentifier=f"com.nsurator.{NAME}", CFBundleInfoDictionaryVersion="6.0",
                    CFBundleName=NAME, CFBundlePackageType="FMWK", CFBundleShortVersionString="1.0.0",
                    CFBundleVersion="1", MinimumOSVersion="17.0")
        (framework / "Info.plist").write_bytes(plistlib.dumps(info))
        shutil.copy2(CORE / f"Artifacts/{NAME}.PrivacyInfo.xcprivacy", framework / "PrivacyInfo.xcprivacy")
        frameworks.append(framework)
    candidate = output / f"{NAME}.xcframework"
    run("xcodebuild", "-create-xcframework", "-framework", frameworks[0], "-framework", frameworks[1], "-output", candidate)
    spec = importlib.util.spec_from_file_location("audit", ROOT / "scripts/audit-ios-ffmpeg-runtime.py")
    audit = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(audit)
    lock = json.loads((ROOT / "scripts/ios-ffmpeg-runtime-lock.json").read_text())
    lock["provenance"] = "CANDIDATE ONLY: pinned FFmpeg 8.1 + maintained VobSub host-I/O patch + dav1d 1.5.4 software AV1; integration/source/license review required before publication."
    lock["required_exported_capabilities"]["av1_software_decoder"] = ["_ff_libdav1d_decoder", "_dav1d_version", "_dav1d_open"]
    lock["required_exported_capabilities"]["paired_vobsub_host_io"] = ["_ff_vobsub_demuxer", "_ff_dvdsub_decoder", "_av_vpc_vobsub_host_io_patch_version"]
    for identifier, _, _, _ in slices:
        framework = candidate / identifier / f"{NAME}.framework"
        lock["slices"][identifier] = dict(binary_sha256=audit.sha256(framework / NAME),
            headers_sha256=audit.tree_sha256(framework / "Headers"),
            modulemap_sha256=audit.sha256(framework / "Modules/module.modulemap"),
            privacy_sha256=audit.sha256(framework / "PrivacyInfo.xcprivacy"))
    lock_path = output / "candidate-runtime-lock.json"
    lock_path.write_text(json.dumps(lock, indent=2) + "\n")
    report = audit.audit(candidate, lock_path)
    (output / "structural-audit.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Candidate staged and structurally audited (NOT release approval): {candidate}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("install", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    stage(args.install, args.output)
