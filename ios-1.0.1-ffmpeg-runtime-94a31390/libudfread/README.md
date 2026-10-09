# libudfread (iOS 1.0.1 runtime)

- Licence: LGPL-2.1-or-later (`COPYING`).
- Source: https://code.videolan.org/videolan/libudfread, commit
  `139a2194525f2745b98a98e4d8fa627d07440176`. This is the commit libbluray
  1.4.1 pins as its `contrib/libudfread` submodule. `git describe` gives
  `1.2.0-3-g139a219`: release 1.2.0 plus three upstream commits.
- Release asset: `libudfread-139a2194525f2745b98a98e4d8fa627d07440176.tar.gz`,
  made with `git archive` from that commit (`git get-tar-commit-id` prints the
  commit id).
- Our changes: none.
- Build: compiled inside libbluray (`-Dembed_udfread=true
  --force-fallback-for=libudfread`), so it ends up in the same static
  libbluray archive and then in `VisionPlayerCoreFFmpegRuntime.framework`.
