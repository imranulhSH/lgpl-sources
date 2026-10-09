# Changes to AMSMB2 4.0.3 and libsmb2 (iOS 1.0.1)

This file is the change notice that LGPL-2.1 section 2(b) asks for.

The patches are in `patches/`. They apply, in numeric order, with
`patch -p1` from the top of an AMSMB2 tree whose `Dependencies/libsmb2`
directory holds libsmb2 (AMSMB2 pins libsmb2 there as a git submodule). The
patches are distributed under the licence of the library they change
(LGPL-2.1-or-later; see `amsmb2/LICENSE` and `libsmb2/COPYING`), with one
exception: the new file `AMSMB2/ReadOnlyFile.swift` that patch 0002 adds is
MIT, as its first line says, like AMSMB2's own Swift sources. It is
distributed as part of the AMSMB2 framework, which as a whole is LGPL-2.1.

| # | Patch | Files changed | Date | What it changes |
|---|---|---|---|---|
| 0001 | `0001-client-guest-session-signing.patch` | `Dependencies/libsmb2/include/libsmb2-private.h`, `Dependencies/libsmb2/lib/init.c`, `Dependencies/libsmb2/lib/libsmb2.c`, `Dependencies/libsmb2/lib/pdu.c` | 2026-10-01 | Keeps the server's Guest/Anonymous session flags apart from the signing requirements. A Guest or Anonymous session does not sign, and refuses an explicit client request to sign or encrypt. A connect call with missing arguments, an open socket or a connection in progress is rejected before it changes the session's settings. |
| 0002 | `0002-persistent-read-only-handle.patch` | `AMSMB2/AMSMB2.swift`; adds `AMSMB2/ReadOnlyFile.swift` | 2026-10-01 | Adds `SMB2Manager.openReadOnlyFile(atPath:)` and the class `SMB2ReadOnlyFile`: a read-only file handle on the existing session for repeated range reads. Each read on the wire is capped at 1 MiB. |
| 0003 | `0003-disconnect-completion-and-status.patch` | `Dependencies/libsmb2/lib/socket.c`, `Dependencies/libsmb2/lib/libsmb2.c` | 2026-10-01 | After a LOGOFF callback closes the socket, the receive loop stops instead of reading from the closed socket. TREE_DISCONNECT and LOGOFF failures report the server's actual status. |

We also added two test programs that are not compiled into the app:
`Dependencies/libsmb2/tests/guest-session-policy.c` and
`Dependencies/libsmb2/tests/disconnect-lifecycle.c` (2026-10-01). They are in
the patched source archive.

No other file was changed. The vendored copy leaves out four upstream files
that are not used by the SwiftPM build: libsmb2's `.github/`, `.gitignore`,
`libsmb2.pc.in` and `packaging/RPM/libsmb2.spec.in`. The upstream archives in
the release include them.
