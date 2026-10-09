# libudfread 1.2.0 (Mac FFmpeg artifact 2026.09.24.1)

- Licence: LGPL-2.1-or-later (`COPYING`).
- Source: https://code.videolan.org/videolan/libudfread/-/archive/1.2.0/libudfread-1.2.0.tar.gz,
  SHA-256 `adcce1190925f9d35a477757c5e3f0e221315d14d3d45b4ae62540ea0925f877`.
- Our changes: none.
- Build: the build copies the unpacked tree into libbluray's
  `contrib/libudfread` and builds it inside libbluray (`-Dembed_udfread=true
  --force-fallback-for=libudfread`), so it ends up in the static libbluray
  archive.
