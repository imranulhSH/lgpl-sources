#!/usr/bin/env python3
"""Reconstruct, offline, the source trees the Apple TV libraries were built from, and check every file.

    python3 reconstruct.py <directory with the four upstream archives> <new directory>

Needs Python 3.12 or later and `patch`. It downloads nothing and compiles nothing.

This is the player core's reconstruct.py (its scripts/package-tvos-source-support.py writes it
into the source packet it makes), changed to read this folder: the archives come from the
directory you name, the patches are the numbered ones in ffmpeg/patches and libbluray/patches,
libudfread is copied into libbluray's contrib/libudfread from its own archive as the build's
prepare-tvos-ffmpeg-sources.py does, and the list of files is records/source-manifest.json.
"""
import hashlib, json, shutil, subprocess, sys, tarfile
from pathlib import Path

if sys.version_info < (3, 12):
    raise SystemExit("Python 3.12 or later is required")
if len(sys.argv) != 3:
    raise SystemExit(__doc__)
here = Path(__file__).resolve().parent
upstream = Path(sys.argv[1]).resolve()
destination = Path(sys.argv[2]).resolve()
if destination.exists():
    raise SystemExit("Destination must not already exist")
manifest = json.loads((here / "records/source-manifest.json").read_text())
components = manifest["components"]
builds = sorted((here / "build").glob("nsurator-player-core-*"))
if len(builds) != 1:
    raise SystemExit("Expected one build/nsurator-player-core-* directory")


def digest(path):
    return hashlib.file_digest(path.open("rb"), "sha256").hexdigest()


for component, spec in components.items():
    archive = upstream / spec["archiveName"]
    if not archive.is_file() or digest(archive) != spec["archiveSHA256"]:
        raise SystemExit("Upstream archive missing or checksum mismatch: " + spec["archiveName"])
destination.mkdir(parents=True)
sources = destination / ".build/tvos-runtime/sources"
sources.mkdir(parents=True)
archives = destination / ".build/tvos-runtime/archives"
archives.mkdir()
for component, spec in components.items():
    archive = upstream / spec["archiveName"]
    shutil.copy2(archive, archives / archive.name)
    with tarfile.open(archive) as handle:
        handle.extractall(sources, filter="data")
# The build compiles libudfread as part of libbluray, from a copy in contrib/libudfread.
shutil.copytree(sources / components["libudfread"]["sourceDirectory"],
                sources / components["libbluray"]["sourceDirectory"] / "contrib/libudfread", dirs_exist_ok=True)
applied = 0
for component, spec in components.items():
    tree = sources / spec["sourceDirectory"]
    for patch in sorted((here / component / "patches").glob("*.patch")):
        subprocess.run(["patch", "--batch", "--fuzz=0", "-p1", "-i", str(patch)], cwd=tree, check=True,
                       stdout=subprocess.PIPE)
        applied += 1
    listed = spec["sourceFiles"]
    for path in sorted(tree.rglob("*")):
        if not path.is_file():
            continue
        name = path.relative_to(tree).as_posix()
        if name in listed:
            continue
        # `patch` keeps the original of a file whose hunks it had to move: not a source file.
        if path.suffix == ".orig" and name[:-5] in listed:
            path.unlink()
            continue
        raise SystemExit("File not in the list: " + component + "/" + name)
    for name, expected in listed.items():
        if digest(tree / name) != expected:
            raise SystemExit("Reconstructed source mismatch: " + component + "/" + name)
for component, spec in components.items():
    # The marker the build's prepare step looks for before it uses a tree.
    (sources / spec["sourceDirectory"] / ".nsurator-verified-source-sha256").write_text(spec["archiveSHA256"] + "\n")
shutil.copytree(builds[0], destination, dirs_exist_ok=True)
print(json.dumps({"verified": True, "components": len(components),
                  "sourceFiles": sum(len(spec["sourceFiles"]) for spec in components.values()),
                  "patchesApplied": applied}))
