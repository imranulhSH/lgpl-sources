# Changes to FFmpeg 8.1.2 (iPhone/iPad FFmpeg runtime 2026.10.10.1)

This file is the change notice that LGPL-2.1 section 2(b) asks for. It lists
each file we changed in FFmpeg 8.1.2 and the date of the change.

The patches are in `patches/`. Apply them in numeric order with
`patch -p1 -N` from the top of the unpacked `ffmpeg-8.1.2` tree. That is what
`../build/nsurator-player-core-307ff71/scripts/apply-ffmpeg-source-patches.sh`
does. The patches are distributed under FFmpeg's licence, LGPL-2.1-or-later
(see `COPYING.LGPLv2.1` and `LICENSE.md`).

This runtime is configured with `--disable-securetransport --disable-protocols`
and only the protocols `async, bluray, cache, concat, concatf, crypto, data, fd,
file, hls, http, pipe, subfile, tcp` (udp comes in through the RTSP demuxer), so
the Secure Transport and libssh files are part of the source tree but are not
built. "Compiled" below says whether the changed file is in the iOS binary.

| # | Patch | Files changed | Date | Compiled | What it changes |
|---|---|---|---|---|---|
| 0001 | `ffmpeg-hls-child-network-options.patch` | `libavformat/aviobuf.c` | 2026-07-12 | yes | Adds TLS, reconnect, redirect and seek options to the list of options a child I/O context inherits from its parent. |
| 0002 | `ffmpeg-securetransport-trust-errors.patch` | `libavformat/tls_securetransport.c` | 2026-07-13 | no | Returns the Secure Transport status for an invalid or bad certificate chain instead of a generic `EIO`. |
| 0003 | `ffmpeg-libssh-host-key-verification.patch` | `libavformat/libssh.c` | 2026-07-13, revised 2026-07-15, field names changed 2026-09-19 | no | Adds `known_hosts` and `verify_host_key` options and verifies the SFTP server's host key; takes the password and private-key passphrase from separate options and clears them from memory after use. |
| 0004 | `ffmpeg-matroska-interrupt-exit.patch` | `libavformat/matroskadec.c` | 2026-07-14 | yes | When reading a cluster is interrupted (`AVERROR_EXIT`), returns that error at once instead of trying to resync. |
| 0005 | `ffmpeg-matroska-invalid-level.patch` | `libavformat/matroskadec.c` | 2026-09-24 | yes | Returns `AVERROR_INVALIDDATA` instead of aborting on an assertion when the element nesting level is invalid, and stops a seek when resetting the read position fails. |
| 0006 | `ffmpeg-http-stale-auth-retry.patch` | `libavformat/http.c` | 2026-07-14 | yes | Lets a 401 or 407 response be retried even when authentication state was already set. |
| 0007 | `ffmpeg-network-dns-error.patch` | `libavformat/tcp.c`, `libavformat/udp.c` | 2026-07-15 | yes | Returns a distinct error code for a failed DNS lookup instead of `EIO`. |
| 0008 | `ffmpeg-hls-presentation-origin-seek.patch` | `libavformat/hls.c` | 2026-10-01 | yes | Lets an HLS VOD rewind to the format's start land on the audio origin that precedes the first video packet. |
| 0009 | `ffmpeg-hls-timeline-epochs.patch` | `libavformat/hls.c` | 2026-10-01 | yes | Gives every HLS input discontinuity epochs, measured epoch clocks and a bounded wait for a playlist refresh, and adds the `avpriv_nsurator_hls_*` functions the player calls. |
| 0010 | `ffmpeg-hls-midplay-subtitle.patch` | `libavformat/hls.c` | 2026-10-01 | yes | Adds the private mid-play WebVTT rendition selection those functions use. |
| 0011 | `ffmpeg-webvtt-hls-timestamp-map.patch` | `libavformat/webvttdec.c` | 2026-10-01 | yes | Adds `hls_timestamp_map` / `hls_timestamp_reference` options, both off by default; with them off parsing is unchanged. |
| 0012 | `ffmpeg-mov-channel-layout-status.patch` | `libavformat/mov.c` | 2026-10-01 | yes | When reading a `chnl` box fails, skips the box and keeps opening the file (upstream FFmpeg's later fix) instead of returning an uninitialised status. |
| 0013 | `ffmpeg-vobsub-host-io-inheritance.patch` | `libavformat/mpeg.c` | 2026-10-02 | yes | The `.sub` file a VobSub index opens inherits the index context's `io_open`, `io_close2`, `opaque` and interrupt callback, and adds `avpriv_nsurator_vobsub_host_io_version()`. |

No other FFmpeg file was changed. Upstream archive:
`https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz`, SHA-256
`464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c`.
