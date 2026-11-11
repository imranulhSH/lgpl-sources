# Provenance (Apple Vision Pro, xros-arm64)

- **Built** 2026-10-20 at 17:09 UTC by `scripts/build_ffmpeg_visionos.sh` in the
  app repository (`nsurator-visionos-native`), from the four archives in
  `scripts/ffmpeg/sources.lock.json` and the 17 patches in
  `scripts/ffmpeg/patches/series` (`build/nsurator-visionos-native/` here holds
  those files). The repository recorded this build in commit `17351ea`
  (2026-10-21), and its FFmpeg build files have not changed since: they are the
  same at commit `d81c336` (2026-11-10).
- **What the app links:** the eight static libraries of the `xros-arm64` slice,
  listed with their SHA-256 in `static-libraries-xros-arm64.sha256`. The tag's
  suffix, `5d1d94b7`, is the start of that file's SHA-256.
- **2026-10-21, app commit `17351ea`:** an unsigned Release archive of the
  app was linked with these libraries. The relinking material made from it was
  checked: the archive's own link command reproduced the executable byte for
  byte, a link from the material's copies of the app's object files and of these
  libraries gave an equivalent executable, and the eight libraries had the
  SHA-256 values listed here.
- **2026-11-10, app commit `d81c336`:** the four archives were unpacked again,
  libudfread was copied into libbluray's `contrib/libudfread` and the 17 patches
  were applied. The result equals, file for file, the trees the libraries were
  built from (11,443 files; only the `.orig` backups `patch` leaves and Meson's
  `.wraplock` are left out). The libraries still have the SHA-256 values listed
  here. `visionos-ffmpeg-static-2026.10.20-5d1d94b7-patched-sources.tar.xz` is that result.
- **Licence switches:** `!CONFIG_GPL=yes`, `!CONFIG_NONFREE=yes` and
  `!CONFIG_VERSION3=yes` in `configure/ffmpeg-xros-arm64-config.mak`;
  `FFMPEG_LICENSE` is "LGPL version 2.1 or later".
- **Paths:** `$WORK` stands for the build's work directory (`artifacts/ffmpeg-work`
  in the app repository) and `$TOOLING` for the Python environment that held
  meson, ninja and pkg-config. FFmpeg compiles its configure line, with the real
  paths, into `libavutil` (`avutil_configuration()`), so that string differs in a
  rebuild made elsewhere.
- **Rebuilt 2026-11-10** from this release's own files with the commands in
  `README.md`, in another directory (Xcode 27.1, visionOS 27.0 SDK): the
  script's checks passed and its probe linked, but all eight libraries differ
  from the shipped ones byte for byte (at least the build's paths, which are
  compiled into them, differ). The comparison of the patched trees above is the
  check that holds.
