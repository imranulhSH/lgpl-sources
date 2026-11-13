# Third-Party Notices

This artifact contains the third-party components below. Include this notice and the
referenced exact license texts in the product's About, acknowledgements, or EULA flow.
This packet records build inputs; it is not legal certification for a downstream app.

| Component | Version | Source archive | License documents |
| --- | --- | --- | --- |
| libbluray | 1.4.1 | `libbluray-1.4.1.tar.gz` | [`libbluray-COPYING`](../../licenses/libbluray-COPYING) |
| dav1d | 1.5.3 | `dav1d-1.5.3.tar.gz` | [`dav1d-COPYING`](../../licenses/dav1d-COPYING) |
| FFmpeg | 8.1.2 | `ffmpeg-8.1.2.tar.xz` | [`FFmpeg-COPYING.LGPLv2.1`](../../licenses/FFmpeg-COPYING.LGPLv2.1), [`FFmpeg-LICENSE.md`](../../licenses/FFmpeg-LICENSE.md) |
| libudfread | 1.2.0 | `libudfread-1.2.0.tar.gz` | [`libudfread-COPYING`](../../licenses/libudfread-COPYING) |

SwiftPM link mode: `framework`.

Required FFmpeg configure flags:

- `--enable-libbluray`
- `--enable-libdav1d`
- `--disable-network`
