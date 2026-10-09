# Changes to libbluray 1.4.1 (Mac FFmpeg artifact 2026.09.24.1)

This file is the change notice that LGPL-2.1 section 2(b) asks for.

The patches are in `patches/`. The build applies them in numeric order with
`patch --batch --forward -p1` from the top of the unpacked `libbluray-1.4.1`
tree (function `apply_libbluray_source_patches` in
`../build/nsurator-player-core/scripts/build-ffmpeg-visionos.sh`). The patches
are distributed under libbluray's licence, LGPL-2.1-or-later (see `COPYING`).

| # | Patch | Files changed | Date | What it changes |
|---|---|---|---|---|
| 0001 | `libbluray-next-coarse-angle-change-point.patch` | `src/libbluray/bdnav/clpi_parse.c` | 2026-07-16, marker renamed 2026-09-19 | When looking for the next angle-change point, moves on to the next coarse entry's range of fine entries instead of restarting at the first fine entry. |
| 0002 | `libbluray-hdmv-menu-button-snapshot.patch` | `src/libbluray/bluray.c`, `src/libbluray/bluray.h`, `src/libbluray/decoders/graphics_controller.c`, `src/libbluray/decoders/graphics_controller.h`, `src/libbluray/decoders/overlay.h` | 2026-07-16, marker renamed 2026-09-19 | Adds a list of the enabled HDMV menu buttons to the Interactive Graphics flush overlay event (overlay interface version 2 to 3) and adds the public function `bd_select_hdmv_menu_button()` to select or activate a button by id. |
| 0003 | `libbluray-disable-decryption-library-loading.patch` | `src/libbluray/disc/aacs.c`, `src/libbluray/disc/bdplus.c` | 2026-07-16, revised 2026-09-19 | Stops libbluray from loading external AACS and BD+ decryption libraries (`libaacs`, `libmmbd`, `libbdplus`). It logs "External AACS/BD+ library loading is disabled by NsuratorPlayerCore." instead. |

No other libbluray file was changed. Before building, the build copies the
unchanged libudfread 1.2.0 tree into `contrib/libudfread` (see
`../libudfread/README.md`).
