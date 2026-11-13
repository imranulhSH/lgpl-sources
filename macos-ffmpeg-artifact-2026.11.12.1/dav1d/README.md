# dav1d 1.5.3 (Mac FFmpeg artifact 2026.11.12.1)

- Licence: BSD-2-Clause (`COPYING`). It is not LGPL; it is here because it is
  linked into the same framework as FFmpeg and is needed to rebuild it.
- Source: https://code.videolan.org/videolan/dav1d/-/archive/1.5.3/dav1d-1.5.3.tar.gz,
  SHA-256 `cbe212b02faf8c6eed5b6d55ef8a6e363aaab83f15112e960701a9c3df813686`.
- Our changes: none.
- Build: meson, static, release; tools, tests, examples and docs off
  (`build-ffmpeg-apple.sh --build-dav1d`; the options are in
  `../records/meson/dav1d-macosx-arm64-build-options.txt`).
