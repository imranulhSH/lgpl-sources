# Changes to libbluray 1.4.1 (iPhone/iPad FFmpeg runtime 2026.10.10.1)

This file is the change notice that LGPL-2.1 section 2(b) asks for.

The patches are in `patches/`. The build applies them in numeric order with
`patch --batch --forward -p1` from the top of the unpacked `libbluray-1.4.1`
tree (`apply_libbluray_source_patches` in
`../build/nsurator-player-core-307ff71/scripts/build-ffmpeg-visionos.sh`). The
patches are distributed under libbluray's licence, LGPL-2.1-or-later (see
`COPYING`).

| # | Patch | Files changed | Date | What it changes |
|---|---|---|---|---|
| 0001 | `libbluray-apple-mobile-java-home.patch` | `src/libbluray/bdj/bdj.c` | 2026-10-01 | On iOS and tvOS, does not try to run `/usr/libexec/java_home` (it does not exist there and process spawning is not allowed); macOS is unchanged. |
| 0002 | `libbluray-next-coarse-angle-change-point.patch` | `src/libbluray/bdnav/clpi_parse.c` | 2026-07-16, marker renamed 2026-09-19 | When looking for the next angle-change point, moves on to the next coarse entry's range of fine entries instead of restarting at the first fine entry. |
| 0003 | `libbluray-hdmv-menu-button-snapshot.patch` | `src/libbluray/bluray.c`, `src/libbluray/bluray.h`, `src/libbluray/decoders/graphics_controller.c`, `src/libbluray/decoders/graphics_controller.h`, `src/libbluray/decoders/overlay.h` | 2026-07-16, marker renamed 2026-09-19 | Adds a list of the enabled HDMV menu buttons to the Interactive Graphics flush overlay event (overlay interface version 2 to 3) and adds the public function `bd_select_hdmv_menu_button()`. |
| 0004 | `libbluray-disable-decryption-library-loading.patch` | `src/libbluray/disc/aacs.c`, `src/libbluray/disc/bdplus.c` | 2026-07-16, revised 2026-09-19 | Stops libbluray from loading external AACS and BD+ decryption libraries (`libaacs`, `libmmbd`, `libbdplus`). |

No other libbluray file was changed. Before building, the build copies the
unchanged libudfread 1.2.0 tree into `contrib/libudfread`
(`build/nsurator-iphone-native/scripts/build-ios-player-core-runtime.sh`).
Upstream archive: `https://code.videolan.org/videolan/libbluray/-/archive/1.4.1/libbluray-1.4.1.tar.gz`,
SHA-256 `e22381a313a231d94ddf9180564b36d803f33bdfc7c0b53c03868bc43e5d163d`.
