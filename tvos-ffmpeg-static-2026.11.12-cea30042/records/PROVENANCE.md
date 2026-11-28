# Provenance (Apple TV, appletvos-arm64)

- **Built** 2026-11-12 at 06:28 UTC by `scripts/build-tvos-ffmpeg-runtime.sh`
  in the shared player core's checkout at commit
  `2e5da9da31164e0155f9b142ab996aeb4ef35cbe` (no uncommitted change,
  `artifact/TVOS-BUILD-EVIDENCE.json`), from the four archives in
  `Config/tvos-ffmpeg-sources.json` and the core's 19 patches
  (`build/nsurator-player-core-2e5da9d/` here holds those files).
- **What the app links:** the eight static libraries of the `appletvos-arm64`
  slice, listed with their SHA-256 in `static-libraries-appletvos-arm64.sha256`.
  The tag's suffix, `cea30042`, is the start of that file's SHA-256. The app's
  own record, `ThirdPartyNotices.manifest.json` in its resources, lists the same
  eight values (`linkEvidence.coreArchiveSHA256`) and names
  `artifact/nsurator-player-core-ffmpeg-apple-manifest.json` and
  `artifact/NSURATOR-ARTIFACT-PROVENANCE.json` by their SHA-256
  (`sourceLocks.coreManifest` `be908acb…`, `sourceLocks.coreProvenance`
  `88f8bcfc…`).
- **Sources checked:** `source-manifest.json` is the list the player core's
  packaging script made from the trees the libraries were compiled from: the
  SHA-256 of each of their 11,443 files. `reconstruct.py` unpacks the four
  archives, applies the numbered patches and compares every file with that
  list; it was run on this release's files as published and verified all of
  them. `tvos-ffmpeg-static-2026.11.12-cea30042-patched-sources.tar.xz` holds
  exactly those files.
- **Not checked:** the libraries have not been built again from this
  release's files, and the app has not been relinked with rebuilt libraries
  (`binaryRebuildVerified` and `appRelinkVerified` are `false` in
  `source-manifest.json`, as the packaging script wrote them).
- **Build paths in the libraries:** none of the eight contains a home
  directory. FFmpeg compiles its configure line into each of its six libraries
  (`configure/ffmpeg-appletvos-arm64-configure.txt`); the line names the
  build's temporary alias `/tmp/nsurator-tvos-core-cbc3434a0d54`, Xcode's
  compiler and SDK, and `/opt/homebrew/bin/pkg-config`. `libavcodec.a` also has
  that alias in ten file-name strings (the paths of `bytestream.h` and `put_bits.h`
  under `sources/ffmpeg-8.1.2/libavcodec/`, which the assertions in those
  headers name). `libbluray.a` and `libdav1d.a` have no path of the build;
  meson's `ar` wrote each member's date and the builder's numeric user and
  group ids into them.
- **Licence switches:** `!CONFIG_GPL=yes`, `!CONFIG_NONFREE=yes` and
  `!CONFIG_VERSION3=yes` in `configure/ffmpeg-appletvos-arm64-config.mak`;
  `FFMPEG_LICENSE` is "LGPL version 2.1 or later". `!CONFIG_NETWORK=yes`: no
  network protocol is compiled.
- **Paths in the records:** `$WORK` stands for the build's work directory
  (`.build/tvos-runtime` in the player core's checkout) and `$TOOLING` for the
  Python environment that held meson and ninja.
  `/tmp/nsurator-tvos-core-cbc3434a0d54` is a link to `$WORK` that the build
  script makes (FFmpeg's configure cannot work in a path with spaces); the
  script names it after the start of the SHA-256 of the work directory's path.
- **Left out of the records:** FFmpeg's `config.log` (configure writes the
  variables of the shell it runs in into that file), meson's own log and
  introspection files (they name the build machine's temporary directory and
  repeat the paths about a thousand times; the cross files and option lines
  here are the configuration), and the `branch` line of
  `TVOS-BUILD-EVIDENCE.json` (an internal branch name; the file as the build
  wrote it has SHA-256
  `a25debfb6f1c87cf4cfef34e657c0b1ca858b29a7294a22135831fdf78ec0c9e`). Of the
  player core's `scripts/` directory, only the scripts this recipe runs are
  here.
