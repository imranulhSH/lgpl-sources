# Nsurator source vendor: AMSMB2

AMSMB2 is copied from https://github.com/amosavian/AMSMB2 at
`1726aaaf7adf63d7d1d2a0c5d1b0e635028215c0`. Its complete checked-out libsmb2
submodule is from https://github.com/sahlberg/libsmb2 at
`aff9fa6ba9f41cfd3c15d184554601ec3f6d8d03`.

This copy retains the two upstream Package manifests, Swift and C sources,
headers, upstream tests, license texts and copyright headers. Git metadata,
SwiftPM build directories and Finder metadata are excluded. Both Package
manifests are unchanged. The SwiftPM `libsmb2` target compiles these C sources;
this is not an opaque binary replacement. `UPSTREAM.json` records exact hashes
and `patches/0001-client-guest-session-signing.patch` contains the production
diff against those pinned source files.

## Local change

The client retains the server's successful SESSION_SETUP Guest/Anonymous flags
separately from connection signing requirements. A Guest/Anonymous session
clears server-derived signing, but refuses an explicit client signing policy
(`smb2_set_sign` or SIGNING_REQUIRED) or encryption policy. It does not derive
signing/encryption keys from supplied credentials for a Guest/Anonymous session.
The SMB 3.1.1 Tree Connect signing exception applies only to those client
sessions; ordinary 3.1.1 sessions still sign even when the server did not require
signing. The server-side PDU behavior is deliberately unchanged.

New authentication, context close and normal disconnect clear session flags.
Caller-requested sign/seal policy is preserved separately from negotiated state,
including the public URL `sign`/`seal` options. Credentials, domain parsing,
negotiated dialect selection and the Swift callback ownership code are unchanged.

Protocol basis:
- https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-smb2/7fd079ca-17e6-4f02-8449-46b606ea289c
- https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-smb2/decadb64-9619-46e5-8892-c634213396d2
- https://learn.microsoft.com/en-us/answers/questions/1824067/ms-smb2-client-behavior-when-server-requires-signi

The older upstream `aa62f28` patch was reverted by `288608f`; this is not a replay
of that patch, because it must preserve ordinary SMB 3.1.1 Tree Connect signing.

## Validation state

The initial Guest-session patch passed seven real local Samba tests and the
separately authorized physical-iPad Guest connection/directory check. Final
rendered playback was not claimed by that connection check.

A subsequent review found that a rejected duplicate/invalid connect could reset
an existing session's negotiated signing/encryption policy. The revised entry
point rejects missing parameters, an active socket, and a pending connection
before changing session policy or ownership fields. The no-network C regression
first failed on the old code and then passed after this guard; it checks signed,
sealed and Guest sessions, invalid arguments and an in-flight connection.

Current revision evidence:
- `.artifacts/smb-guest-c-policy-20261001-r2/result.json`: compiled against the
  real C sources for macOS arm64; assertions passed, no compiler diagnostics.
- `.artifacts/smb-guest-regression-guard-20261001-r3/run.json`: seven real local
  Samba tests passed, including Guest and authenticated wire signing/sealing.
- `.artifacts/physical-ipad-debug-20261001-r9/run.json`: rebuilt with the reset
  guard; real iPad Guest listing, streaming, seek, rendered frame capture and
  remote history passed for one MKV. Subsequent player seek regressions on a
  second MKV are tracked in `docs/development/physical-ipad-nas-20261001.json`;
  this connection evidence does not claim complete playback acceptance.

`Dependencies/libsmb2/tests/guest-session-policy.c` is excluded from production
SwiftPM sources. The C regression and Samba tests use no external NAS; the
physical acceptance reads only the separately authorized NAS test directory.

Original licenses remain authoritative: `LICENSE`,
`Dependencies/libsmb2/COPYING`, `Dependencies/libsmb2/LICENCE-LGPL-2.1.txt`, and
per-source notices. This local modification does not replace those obligations.

## Disconnect completion and status (patch 0003)

`patches/0003-disconnect-completion-and-status.patch` follows the existing Guest
and persistent-read patches. A successful LOGOFF callback intentionally closes
the context socket. The receive loop now returns instead of attempting another
read on fd -1. Previously that read produced EBADF and a generic service -1,
which the Swift wrapper displayed as EPERM after discarding the error context.

TREE_DISCONNECT and LOGOFF failures now retain their actual NTSTATUS and mapped
errno. A refused disconnect is not treated as success, and allocation failures
still use ENOMEM. This patch changes no stat access bits, Guest policy, signing,
encryption, Swift callback ownership, package manifests or licenses.

Run the permanent local contracts with:

```sh
python3 scripts/test-smb-disconnect.py
```

The runner compiles the current C sources with ASan and UBSan by default. Its
six disconnect cases exchange real protocol messages through AF_UNIX socketpairs:
success, two TREE_DISCONNECT failures, two LOGOFF failures and a peer closing
before reply. It checks callback completion, original failure status, absence of
reads on a closed descriptor and descriptor cleanup. The same runner also runs
the existing Guest/session policy contract. It does not contact a NAS or perform
an authentication handshake. Before/after input hashes and full compiler/test
logs are retained under the selected ignored artifact directory.

Current integrated C and local-Samba regression paths are recorded in
`UPSTREAM.json` under `disconnectLifecycle`; physical verification remains a
separate scope owned by the device acceptance run.
