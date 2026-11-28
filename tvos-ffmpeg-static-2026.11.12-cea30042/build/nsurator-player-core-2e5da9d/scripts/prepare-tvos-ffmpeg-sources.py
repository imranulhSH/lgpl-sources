#!/usr/bin/env python3
"""Fetch only lock-listed sources; validate digests before safe extraction."""
import argparse
import hashlib
import json
import shutil
import tarfile
import urllib.request
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--lock', type=Path, required=True)
parser.add_argument('--root', type=Path, required=True)
args = parser.parse_args()
lock = json.loads(args.lock.read_text())
archives = args.root / 'archives'
sources = args.root / 'sources'
archives.mkdir(parents=True, exist_ok=True)
sources.mkdir(parents=True, exist_ok=True)
for component, spec in lock['sources'].items():
    archive = archives / spec['archiveName']
    if archive.name != spec['archiveName'] or not spec['url'].startswith('https://'):
        raise ValueError('Invalid archive lock entry')
    if not archive.exists():
        partial = archive.with_suffix(archive.suffix + '.download')
        with urllib.request.urlopen(spec['url'], timeout=60) as response, partial.open('wb') as output:
            shutil.copyfileobj(response, output)
        partial.replace(archive)
    digest = hashlib.file_digest(archive.open('rb'), 'sha256').hexdigest()
    if digest != spec['sha256']:
        raise ValueError(f'Source checksum mismatch: {component}')
    destination = sources / f"{component}-{spec['version']}"
    marker = destination / '.nsurator-verified-source-sha256'
    # Existing development trees may contain project source patches; preserve
    # those only when the source origin has already been recorded explicitly.
    if not marker.exists():
        if destination.exists():
            raise ValueError(f'Unrecorded existing source tree: {destination}; retain it separately before rebuilding')
        with tarfile.open(archive) as handle:
            handle.extractall(sources, filter='data')
        marker.write_text(digest + '\n')
    elif marker.read_text().strip() != digest:
        raise ValueError(f'Source origin differs from lock: {component}')
    print(f'Verified {component} {spec["version"]}', flush=True)
bluray = sources / ('libbluray-' + lock['sources']['libbluray']['version'])
udf = sources / ('libudfread-' + lock['sources']['libudfread']['version'])
shutil.copytree(udf, bluray / 'contrib/libudfread', dirs_exist_ok=True)
