# Provenance (Apple Vision Pro, xros-arm64)

- **Built** 2026-11-11 at 12:42 UTC by `scripts/build_ffmpeg_visionos.sh` in the
  app repository (`nsurator-visionos-native`, commit `6355d40`), from the
  four archives in `scripts/ffmpeg/sources.lock.json` and the 17 patches in
  `scripts/ffmpeg/patches/series` (`build/nsurator-visionos-native/` here holds
  those files).
- **Replaces `visionos-ffmpeg-static-2026.10.20-5d1d94b7`**, which no distributed build used: the same
  archives, patches and configure options, built 2026-10-20. Those libraries had
  the build's paths compiled into them. FFmpeg keeps its configure line in each
  of its libraries (`avutil_configuration()` and the others), and that line named
  the work directory, the Python environment that held pkg-config, and Xcode;
  ten assertion messages in libavcodec's bitstream filters named the source
  directory. The recipe now runs FFmpeg's `configure` through a relative `src/`
  link, takes the SDK from `SDKROOT`, finds clang and pkg-config on `PATH`, lets
  pkg-config supply dav1d's and libbluray's flags, and installs with
  `make install prefix=<stage>`. The configure line has no path any more
  (`records/configure/ffmpeg-xros-arm64-configure.txt`), every source path
  compiled in is relative (such as `src/libavcodec/bytestream.h`), and the
  script refuses a library that contains `/Users/`, `/Applications/`,
  `/Volumes/`, `/private/` or its work directory.
- **Compared with the 2026-10-20 libraries:** each of the six FFmpeg libraries
  has the same members, and every member's code, data and relocations are the
  same; only the configure-line string and those ten paths changed.
  `libdav1d.a` and `libbluray.a` are the 2026-10-20 files, byte for byte (meson
  found nothing to rebuild).
- **What the app links:** the eight static libraries of the `xros-arm64` slice,
  listed with their SHA-256 in `static-libraries-xros-arm64.sha256`. The tag's
  suffix, `e9f11afc`, is the start of that file's SHA-256.
- **Rebuilt 2026-11-11** with the same recipe in another directory (Xcode 27.1):
  the six FFmpeg libraries came out byte for byte the same. In `libdav1d.a` and
  `libbluray.a` every member came out byte for byte the same (72 and 60
  members); the archives differ only in the dates and owner ids that meson's
  `ar` writes into the member headers. That rebuild unpacked the four archives
  again, copied libudfread into libbluray's `contrib/libudfread` and applied the
  17 patches; the result equals, file for file, the trees the libraries were
  built from (11,443 files; the `.orig` backups `patch` leaves, Meson's
  `.wraplock` and the build's marker are left out).
  `visionos-ffmpeg-static-2026.11.11-e9f11afc-patched-sources.tar.xz` is that result.
- **2026-11-11, app commit `82198a7`:** an unsigned Release archive of the app
  was linked with these libraries. It validated with no directory of the
  building Mac in its executable or its SMB framework; the executable carries
  FFmpeg's configure line as recorded here.
- **Licence switches:** `!CONFIG_GPL=yes`, `!CONFIG_NONFREE=yes` and
  `!CONFIG_VERSION3=yes` in `configure/ffmpeg-xros-arm64-config.mak`;
  `FFMPEG_LICENSE` is "LGPL version 2.1 or later".
- **Paths in the records:** `$WORK` stands for the build's work directory
  (`artifacts/ffmpeg-work` in the app repository) and `$TOOLING` for the Python
  environment that held meson, ninja and pkg-config. The libraries contain no
  path of the build.
