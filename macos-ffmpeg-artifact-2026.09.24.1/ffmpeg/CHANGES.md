# Changes to FFmpeg 8.1.2 (Mac FFmpeg artifact 2026.09.24.1)

This file is the change notice that LGPL-2.1 section 2(b) asks for. It lists
each file we changed in FFmpeg 8.1.2 and the date of the change.

The patches are in `patches/`. Apply them in numeric order with
`patch -p1 -N` from the top of the unpacked `ffmpeg-8.1.2` tree. That is what
`../build/nsurator-player-core/scripts/apply-ffmpeg-source-patches.sh` does.
The patches are distributed under FFmpeg's licence, LGPL-2.1-or-later (see
`COPYING.LGPLv2.1` and `LICENSE.md`).

This artifact is configured with `--disable-network`, so only the changes to
`aviobuf.c` and `matroskadec.c` are compiled into the Mac app. The other
changed files are part of the source tree but are not built.

| # | Patch | Files changed | Date | Compiled | What it changes |
|---|---|---|---|---|---|
| 0001 | `ffmpeg-hls-child-network-options.patch` | `libavformat/aviobuf.c` | 2026-07-12 | yes | Adds TLS, reconnect, redirect and seek options to the list of options a child I/O context inherits from its parent. |
| 0002 | `ffmpeg-securetransport-trust-errors.patch` | `libavformat/tls_securetransport.c` | 2026-07-13 | no | Returns the Secure Transport status for an invalid or bad certificate chain instead of a generic `EIO`. |
| 0003 | `ffmpeg-libssh-host-key-verification.patch` | `libavformat/libssh.c` | 2026-07-13, revised 2026-07-15, field names changed 2026-09-19 | no | Adds `known_hosts` and `verify_host_key` options and verifies the SFTP server's host key; takes the password and private-key passphrase from separate options and clears them from memory after use. |
| 0004 | `ffmpeg-matroska-interrupt-exit.patch` | `libavformat/matroskadec.c` | 2026-07-14 | yes | When reading a cluster is interrupted (`AVERROR_EXIT`), returns that error at once instead of trying to resync. |
| 0005 | `ffmpeg-matroska-invalid-level.patch` | `libavformat/matroskadec.c` | 2026-09-24 | yes | Returns `AVERROR_INVALIDDATA` instead of aborting on an assertion when the element nesting level is invalid, and stops a seek when resetting the read position fails. |
| 0006 | `ffmpeg-http-stale-auth-retry.patch` | `libavformat/http.c` | 2026-07-14 | no | Lets a 401 or 407 response be retried even when authentication state was already set. |
| 0007 | `ffmpeg-network-dns-error.patch` | `libavformat/tcp.c`, `libavformat/udp.c` | 2026-07-15 | no | Returns a distinct error code for a failed DNS lookup instead of `EIO`. |

No other FFmpeg file was changed. Upstream archive:
`https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz`, SHA-256
`464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c`.
