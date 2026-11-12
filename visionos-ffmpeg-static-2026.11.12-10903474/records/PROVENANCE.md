# Provenance (Apple Vision Pro, xros-arm64)

- **Built** 2026-11-12 at 05:02 UTC by `scripts/build_ffmpeg_visionos.sh` in the
  app repository (`nsurator-visionos-native`, commit `8f708bf`), from the
  four archives in `scripts/ffmpeg/sources.lock.json` and the 19 patches in
  `scripts/ffmpeg/patches/series` (`build/nsurator-visionos-native/` here holds
  those files).
- **Replaces `visionos-ffmpeg-static-2026.11.11-e9f11afc`**, which no distributed build used: the same
  archives and configure options and the same 17 patches, with two more. The
  app's player core moved to its main branch, which seeks in a Matroska file
  through the block its cue names (0014) and can leave a font attachment's
  data unread while it opens a file (0015, an option the app leaves off). Both
  patches are the shared player core's, byte for byte, and the iPhone/iPad
  release `ios-ffmpeg-runtime-2026.11.09.1-6e09d2b2` has them under the same
  numbers.
- **Compared with the libraries of `visionos-ffmpeg-static-2026.11.11-e9f11afc`:** six of the eight are
  the same files, byte for byte (`libavcodec.a`, `libavfilter.a`, `libavutil.a`,
  `libswresample.a`, `libswscale.a` and `libdav1d.a`). In `libavformat.a`, of
  its 485 members only `matroskadec.o` changed (the two patches). In
  `libbluray.a` every member is the same; the archive differs in the members'
  headers, because the build compiled the patched libbluray files again (it
  unpacks and patches the sources afresh when the patch set changes).
- **What the app links:** the eight static libraries of the `xros-arm64` slice,
  listed with their SHA-256 in `static-libraries-xros-arm64.sha256`. The tag's
  suffix, `10903474`, is the start of that file's SHA-256.
- **Rebuilt** with the same recipe and Xcode in another work directory, from
  scratch: the six FFmpeg libraries came out byte for byte the same, and in
  `libdav1d.a` and `libbluray.a` every member is the same (71 and 59 members;
  the archives differ only in the dates and owner ids in the member headers).
  That build unpacked and patched the four archives too, and its trees hold
  the same files, file for file.
  `visionos-ffmpeg-static-2026.11.12-10903474-patched-sources.tar.xz` is the four trees these libraries were built
  from, after patching (11,443 files; the `.orig` backups `patch` leaves,
  Meson's `.wraplock` and the build's marker are left out).
- **2026-11-12, app commit `ad38a2f`:** an unsigned Release archive of the app
  was linked with these libraries. It validated (no directory of the building
  Mac in its executable or its SMB framework; the offer page links this
  release), and the relinking materials made from it relinked the executable.
- **Licence switches:** `!CONFIG_GPL=yes`, `!CONFIG_NONFREE=yes` and
  `!CONFIG_VERSION3=yes` in `configure/ffmpeg-xros-arm64-config.mak`;
  `FFMPEG_LICENSE` is "LGPL version 2.1 or later".
- **Paths in the records:** `$WORK` stands for the build's work directory
  (`artifacts/ffmpeg-work` in the app repository) and `$TOOLING` for the Python
  environment that held meson, ninja and pkg-config. The libraries contain no
  path of the build.
