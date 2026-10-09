# Changes to FFmpeg 8.1 (iOS 1.0.1 runtime)

This file is the change notice that LGPL-2.1 section 2(b) asks for. It lists
each file we changed in FFmpeg 8.1 and the date of the change.

The patches are in `patches/`. Apply them in numeric order with
`patch -p1 -N` from the top of the unpacked `ffmpeg-8.1` tree. That is what
`../build/Packages/vision-player-core/scripts/apply-ffmpeg-source-patches.sh`
does. The patches are distributed under FFmpeg's licence,
LGPL-2.1-or-later (see `COPYING.LGPLv2.1` and `LICENSE.md`).

"Compiled" says whether the changed file is part of this runtime's build
configuration (`../build/Packages/vision-player-core/Artifacts/BuildProvenance/ffmpeg-iphoneos-arm64-config.mak`).

| # | Patch | Files changed | Date | Compiled | What it changes |
|---|---|---|---|---|---|
| 0001 | `ffmpeg-hls-child-network-options.patch` | `libavformat/aviobuf.c` | 2026-07-12 | yes | Adds TLS, reconnect, redirect and seek options to the list of options a child I/O context (for example an HLS segment) inherits from its parent. |
| 0002 | `ffmpeg-securetransport-trust-errors.patch` | `libavformat/tls_securetransport.c` | 2026-07-13 | yes | Returns the Secure Transport status for an invalid or bad certificate chain instead of a generic `EIO`, so the caller can tell a trust failure from an I/O failure. |
| 0003 | `ffmpeg-libssh-host-key-verification.patch` | `libavformat/libssh.c` | 2026-07-13, revised 2026-07-15 | no (libssh is not enabled) | Adds `known_hosts` and `verify_host_key` options and verifies the SFTP server's host key; takes the password and private-key passphrase from separate options and clears them from memory after use. |
| 0004 | `ffmpeg-matroska-interrupt-exit.patch` | `libavformat/matroskadec.c` | 2026-07-14 | yes | When reading a cluster is interrupted (`AVERROR_EXIT`), returns that error at once instead of trying to resync. |
| 0005 | `ffmpeg-http-stale-auth-retry.patch` | `libavformat/http.c` | 2026-07-14 | yes | Lets a 401 or 407 response be retried even when authentication state was already set, so stale credentials can be replaced. |
| 0006 | `ffmpeg-network-dns-error.patch` | `libavformat/tcp.c`, `libavformat/udp.c` | 2026-07-15 | yes | Returns a distinct error code for a failed DNS lookup instead of `EIO`; `udp.c` returns the real resolver result. |
| 0007 | `ffmpeg-vobsub-host-io-inheritance.patch` | `libavformat/mpeg.c` | 2026-09-30 | yes | The VobSub demuxer's inner MPEG context inherits the caller's `io_open`, `io_close2`, `opaque` and interrupt callback. Adds the exported function `av_vpc_vobsub_host_io_patch_version()`, which returns 1. |

No other FFmpeg file was changed. Upstream archive:
`https://ffmpeg.org/releases/ffmpeg-8.1.tar.xz`, SHA-256
`b072aed6871998cce9b36e7774033105ca29e33632be5b6347f3206898e0756a`.
