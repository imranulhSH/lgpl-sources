#!/usr/bin/env python3
import datetime
import hashlib
import json
import subprocess
import sys
from pathlib import Path
core, artifact = map(Path, sys.argv[1:])
def git(*args):
    return subprocess.check_output(['git', '-C', str(core), *args], text=True).strip()
patch = subprocess.check_output(['git', '-C', str(core), 'diff', 'HEAD', '--binary'])
manifest = {
    'schemaVersion': 1,
    'builtAtUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'branch': git('branch', '--show-current'),
    'sourceCommit': git('rev-parse', 'HEAD'),
    'trackedDiffSHA256': hashlib.sha256(patch).hexdigest(),
    'gitStatus': git('status', '--short'),
    'untrackedSourceSHA256': {name: hashlib.sha256((core / name).read_bytes()).hexdigest() for name in git('ls-files', '--others', '--exclude-standard').splitlines() if (core / name).is_file()},
    'xcode': subprocess.check_output(['xcodebuild', '-version'], text=True).strip(),
    'scope': 'Static artifact build and platform metadata only. Playback, rendering and HDMI unverified.',
    'libraries': {str(p.relative_to(artifact)): hashlib.file_digest(p.open('rb'), 'sha256').hexdigest() for p in sorted(artifact.rglob('*.a'))},
}
(artifact / 'TVOS-BUILD-EVIDENCE.json').write_text(json.dumps(manifest, indent=2) + '\n')
