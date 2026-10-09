# Changes to libbluray 1.4.1 (iOS 1.0.1 runtime)

This file is the change notice that LGPL-2.1 section 2(b) asks for.

The build applied three changes to libbluray at commit
`7d94f2660af5bfc16015291a03539329135c18f1` (tag `1.4.1`). After the build,
the combined difference was recorded with `git diff --binary` as
`patches/libbluray-vpc-ios.patch`. That is the file to apply:

```sh
patch -d libbluray -p1 -N < patches/libbluray-vpc-ios.patch
```

`patches/individual/` holds the same three changes as separate patches, in the
order the build script applies them. Applying the three of them gives a tree
identical to applying the combined patch (checked when this release was made).
The patches are distributed under libbluray's licence, LGPL-2.1-or-later (see
`COPYING`).

| # | Patch | Files changed | Date | What it changes |
|---|---|---|---|---|
| 1 | `libbluray-next-coarse-angle-change-point.patch` | `src/libbluray/bdnav/clpi_parse.c` | 2026-07-16 | When looking for the next angle-change point, moves on to the next coarse entry's range of fine entries instead of restarting at the first fine entry. |
| 2 | `libbluray-hdmv-menu-button-snapshot.patch` | `src/libbluray/bluray.c`, `src/libbluray/bluray.h`, `src/libbluray/decoders/graphics_controller.c`, `src/libbluray/decoders/graphics_controller.h`, `src/libbluray/decoders/overlay.h` | 2026-07-16 | Adds a list of the enabled HDMV menu buttons to the Interactive Graphics flush overlay event (overlay interface version 2 to 3) and adds the public function `bd_select_hdmv_menu_button()` to select or activate a button by id. |
| 3 | `libbluray-disable-decryption-library-loading.patch` | `src/libbluray/disc/aacs.c`, `src/libbluray/disc/bdplus.c` | 2026-07-16 | Stops libbluray from loading external AACS and BD+ decryption libraries (`libaacs`, `libmmbd`, `libbdplus`). It logs "External AACS/BD+ library loading is disabled by VisionPlayerCore." instead. |

No other libbluray file was changed. libudfread, embedded in
`contrib/libudfread`, is unchanged (see `../libudfread/`).
