# Changes to FFmpeg 8.1.2 (Mac FFmpeg artifact 2026.11.12.1)

This file is the change notice that LGPL-2.1 section 2(b) asks for. It lists
each file we changed in FFmpeg 8.1.2 and the date of the change.

The patches are in `patches/`. Apply them in numeric order with
`patch -p1 -N` from the top of the unpacked `ffmpeg-8.1.2` tree. The numbers
are the order in which
`../build/nsurator-player-core-e4e032f/scripts/apply-ffmpeg-source-patches.sh`
applies them; that script applies 0004–0007 (all `matroskadec.c`) and
0010–0012 (all `hls.c`) as stacks, without fuzz. The patches are distributed
under FFmpeg's licence, LGPL-2.1-or-later (see `COPYING.LGPLv2.1` and
`LICENSE.md`).

They are the same 15 files, byte for byte, as in the iPhone/iPad release
`ios-ffmpeg-runtime-2026.11.09.1-6e09d2b2`, which numbers them in the order
they were added: 0001–0005 are numbered alike, that release's 0014 and 0015
are 0006 and 0007 here, and its 0006–0013 are 0008–0015 here.

This artifact is configured with `--disable-network` and without libssh, so
`http.c`, `tcp.c`, `udp.c`, `tls_securetransport.c` and `libssh.c` are part of
the source tree but are not built. "Compiled" below says whether the changed
file is in the Mac framework: 11 of the 15 patches are, 4 are not.

| # | Patch | Files changed | Date | Compiled | What it changes |
|---|---|---|---|---|---|
| 0001 | `ffmpeg-hls-child-network-options.patch` | `libavformat/aviobuf.c` | 2026-07-12 | yes | Adds TLS, reconnect, redirect and seek options to the list of options a child I/O context inherits from its parent. |
| 0002 | `ffmpeg-securetransport-trust-errors.patch` | `libavformat/tls_securetransport.c` | 2026-07-13 | no | Returns the Secure Transport status for an invalid or bad certificate chain instead of a generic `EIO`. |
| 0003 | `ffmpeg-libssh-host-key-verification.patch` | `libavformat/libssh.c` | 2026-07-13, revised 2026-07-15, field names changed 2026-09-19 | no | Adds `known_hosts` and `verify_host_key` options and verifies the SFTP server's host key; takes the password and private-key passphrase from separate options and clears them from memory after use. |
| 0004 | `ffmpeg-matroska-interrupt-exit.patch` | `libavformat/matroskadec.c` | 2026-07-14 | yes | When reading a cluster is interrupted (`AVERROR_EXIT`), returns that error at once instead of trying to resync. |
| 0005 | `ffmpeg-matroska-invalid-level.patch` | `libavformat/matroskadec.c` | 2026-09-24 | yes | Returns `AVERROR_INVALIDDATA` instead of aborting on an assertion when the element nesting level is invalid, and stops a seek when resetting the read position fails. |
| 0006 | `ffmpeg-matroska-cue-relative-position.patch` | `libavformat/matroskadec.c` | 2026-11-08, revised the same day | yes | A seek in a Matroska file goes straight to the block its cue names (the cue's `CueRelativePosition` within its cluster), reading nothing of the cluster before it; the cluster's time is checked against every cue of that cluster, a bitmap subtitle's display sets are kept whatever their cue's duration, a segment whose last cluster the seek jumped into ends cleanly, and a position or duration of 2^40 or more in the file is taken as not given. Adds the matroska demuxer's `cue_relative_seek` and `cue_relative_seek_subtitle_margin` options. |
| 0007 | `ffmpeg-matroska-skip-attachment-data.patch` | `libavformat/matroskadec.c` | 2026-11-09 | yes | The matroska demuxer's `skip_attachment_data` option (off unless set): at open, the data of an attachment that is not a picture (a font) is skipped, not read, and its stream's metadata says where it lies in the file (`file_offset`, `file_size`); an attachment whose type comes after its data, and every picture, is read as before. Joins 0006's option table. |
| 0008 | `ffmpeg-http-stale-auth-retry.patch` | `libavformat/http.c` | 2026-07-14 | no | Lets a 401 or 407 response be retried even when authentication state was already set. |
| 0009 | `ffmpeg-network-dns-error.patch` | `libavformat/tcp.c`, `libavformat/udp.c` | 2026-07-15 | no | Returns a distinct error code for a failed DNS lookup instead of `EIO`. |
| 0010 | `ffmpeg-hls-presentation-origin-seek.patch` | `libavformat/hls.c` | 2026-10-01 | yes | Lets an HLS VOD rewind to the format's start land on the audio origin that precedes the first video packet. |
| 0011 | `ffmpeg-hls-timeline-epochs.patch` | `libavformat/hls.c` | 2026-10-01 | yes | Gives every HLS input discontinuity epochs, measured epoch clocks and a bounded wait for a playlist refresh, and adds the `avpriv_nsurator_hls_*` functions the player calls. |
| 0012 | `ffmpeg-hls-midplay-subtitle.patch` | `libavformat/hls.c` | 2026-10-01 | yes | Adds the private mid-play WebVTT rendition selection those functions use. |
| 0013 | `ffmpeg-webvtt-hls-timestamp-map.patch` | `libavformat/webvttdec.c` | 2026-10-01 | yes | Adds `hls_timestamp_map` / `hls_timestamp_reference` options, both off by default; with them off parsing is unchanged. |
| 0014 | `ffmpeg-mov-channel-layout-status.patch` | `libavformat/mov.c` | 2026-10-01, revised 2026-10-02 | yes | When reading a `chnl` box fails, skips the box and keeps opening the file (upstream FFmpeg's later fix) instead of returning an uninitialised status. |
| 0015 | `ffmpeg-vobsub-host-io-inheritance.patch` | `libavformat/mpeg.c` | 2026-10-02 | yes | The `.sub` file a VobSub index opens inherits the index context's `io_open`, `io_close2`, `opaque` and interrupt callback, and adds `avpriv_nsurator_vobsub_host_io_version()`. |

No other FFmpeg file was changed. Upstream archive:
`https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz`, SHA-256
`464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c`.
