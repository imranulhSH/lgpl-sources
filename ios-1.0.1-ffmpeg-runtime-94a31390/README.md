# iPhone and iPad app 1.0.1 (101): FFmpeg runtime

Release tag: `ios-1.0.1-ffmpeg-runtime-94a31390`

This folder and its release are the corresponding source for
`VisionPlayerCoreFFmpegRuntime.framework`, the media library framework inside
Nsurator for iPhone and iPad 1.0.1 (build 101).

## The shipped binary

| | |
|---|---|
| Path in the app | `NsuratorPhone.app/Frameworks/VisionPlayerCoreFFmpegRuntime.framework/VisionPlayerCoreFFmpegRuntime` |
| Linking | Dynamic framework. Install name `@rpath/VisionPlayerCoreFFmpegRuntime.framework/VisionPlayerCoreFFmpegRuntime`, compatibility version 1.0.0. |
| Device slice (ios-arm64) SHA-256 | `94a313906f3262f878265265791ffd00bf2a7de77d9796e1fa35e53650e82f42` |
| Pinned by | `build/scripts/ios-ffmpeg-runtime-lock.json` |
| Contains | FFmpeg, libbluray, libudfread and dav1d. No app code. |

The framework is built by linking one merged static archive of the libraries
below into a dynamic library (`build/scripts/stage-ios-ffmpeg-candidate.py`).
The app executable links to it at run time.

## Components

| Component | Licence | Upstream source | Release asset | SHA-256 | Our changes |
|---|---|---|---|---|---|
| FFmpeg 8.1 (libavformat, libavcodec, libavutil, libswresample, libswscale) | LGPL-2.1-or-later | https://ffmpeg.org/releases/ffmpeg-8.1.tar.xz | `ffmpeg-8.1.tar.xz` | `b072aed6871998cce9b36e7774033105ca29e33632be5b6347f3206898e0756a` | 7 patches, see `ffmpeg/CHANGES.md` |
| libbluray 1.4.1, commit `7d94f2660af5bfc16015291a03539329135c18f1` (tag `1.4.1`) | LGPL-2.1-or-later | https://code.videolan.org/videolan/libbluray | `libbluray-1.4.1.tar.gz` | `e22381a313a231d94ddf9180564b36d803f33bdfc7c0b53c03868bc43e5d163d` | 3 changes, see `libbluray/CHANGES.md` |
| libudfread, commit `139a2194525f2745b98a98e4d8fa627d07440176` (1.2.0 plus 3 commits) | LGPL-2.1-or-later | https://code.videolan.org/videolan/libudfread | `libudfread-139a2194525f2745b98a98e4d8fa627d07440176.tar.gz` | `655281dd977ad5973899554bb168509f1bca37132b74daa79c5ab10e47c7b100` | none |
| dav1d 1.5.4 | BSD-2-Clause | https://download.videolan.org/pub/videolan/dav1d/1.5.4/dav1d-1.5.4.tar.xz | `dav1d-1.5.4.tar.xz` | `686616b7c69eb88d44459391ab25cac13b6647a3b288835c5784e71c1514a5c5` | none |

Notes on the archives:

- `ffmpeg-8.1.tar.xz` and `dav1d-1.5.4.tar.xz` were downloaded again from the
  URLs above on 2026-10-09 and match the SHA-256 values the build recorded.
- The build cloned libbluray with git at the commit above. `libbluray-1.4.1.tar.gz`
  is code.videolan.org's archive of tag `1.4.1`. Its contents are identical to
  that commit; this was checked file by file when this release was made.
- libudfread is a git submodule of libbluray, so it has no release archive.
  The asset was made with `git archive` from the verified commit;
  `git get-tar-commit-id` on the uncompressed tar prints the commit id.

## Build configuration

- FFmpeg configure line (device slice, from
  `build/Packages/vision-player-core/Artifacts/BuildProvenance/ffmpeg-iphoneos-arm64-config.mak`):
  `--enable-cross-compile --target-os=darwin --arch=arm64 --enable-static --disable-shared --enable-pic --disable-programs --disable-doc --disable-debug --disable-avdevice --disable-devices --enable-avcodec --enable-avformat --enable-avutil --enable-swresample --enable-swscale --enable-libbluray --enable-videotoolbox --enable-libdav1d`,
  plus `--prefix`, `--cc`, `--sysroot`, `--pkg-config` and
  `-target arm64-apple-ios17.0` compiler and linker flags.
- GPL, nonfree and version3 are all off (`!CONFIG_GPL`, `!CONFIG_NONFREE`,
  `!CONFIG_VERSION3` in the config record).
- Compiler: Apple clang 21.0.0 (clang-2100.3.34.2), iPhoneOS 27.0 SDK,
  minimum iOS 17.0.
- libbluray: meson, static, release; tools, devtools, examples and docs off;
  `-Dbdj_jar=disabled -Dfreetype=disabled -Dfontconfig=disabled -Dlibxml2=disabled -Dembed_udfread=true --force-fallback-for=libudfread`.
- dav1d: meson, static, release; tools, tests, examples and docs off.
- `libavfilter` is built by the scripts but is not merged into the framework.

## Folder contents

| Path | What it is |
|---|---|
| `ffmpeg/patches/` | The 7 FFmpeg patches, numbered in the order they are applied |
| `ffmpeg/CHANGES.md` | Dated change notices for FFmpeg |
| `libbluray/patches/libbluray-vpc-ios.patch` | The libbluray difference the build recorded |
| `libbluray/patches/individual/` | The same changes as three separate patches |
| `libbluray/CHANGES.md` | Dated change notices for libbluray |
| `libudfread/`, `dav1d/` | Licences and source notes (no changes) |
| `*/COPYING*`, `ffmpeg/LICENSE.md` | Licence texts taken from the upstream sources |
| `build/` | The build scripts and records, in the same layout as in the app repository at commit `074e2f5` |
| `records/app-imports-from-VisionPlayerCoreFFmpegRuntime.txt` | The 103 C symbols the app imports from the framework (taken from a Debug simulator build of the same commit) |
| `release-assets.sha256` | SHA-256 of every file attached to the release |

## Rebuilding

You need a Mac with Xcode (the shipped build used the iPhoneOS 27.0 SDK),
meson, ninja, pkg-config and python3.

The simplest path downloads and checks the same sources and builds everything:

```sh
build/scripts/rebuild-ios-ffmpeg-runtime.sh /absolute/path/to/a/new/directory
```

The directory must not exist yet and its path must not contain spaces. The
script builds dav1d, libbluray and FFmpeg for `iphoneos-arm64`,
`iphonesimulator-arm64` and `macosx-arm64` with the `base` link profile,
applies the patches (the scripts skip patches that are already applied), and
then `stage-ios-ffmpeg-candidate.py` links the framework and writes an
XCFramework candidate and an audit report.

To build from the release assets instead of downloading, unpack
`ios-1.0.1-ffmpeg-runtime-94a31390-build-scripts-and-records.tar.gz` and
`ios-1.0.1-ffmpeg-runtime-94a31390-patched-sources.tar.xz` into one new,
empty directory with `--strip-components=1` (so that `build/` and `sources/`
sit side by side), point
`FFMPEG_SOURCE_DIR`, `LIBBLURAY_SOURCE_DIR` and `DAV1D_SOURCE_DIR` at the
unpacked `sources/ffmpeg-8.1`, `sources/libbluray` and `sources/dav1d-1.5.4`,
set the other variables the way `rebuild-ios-ffmpeg-runtime.sh` sets them,
and run its three `build-ffmpeg-apple.sh` steps and the staging step.

Always set `VISION_PLAYER_CORE_FFMPEG_LINK_PROFILE=base`, as the rebuild
script does. The scripts' default profile (`full`) adds DVD libraries that
FFmpeg treats as GPL; that profile was not used for the app.

A rebuild does not reproduce the binary hash exactly, because the build
directory paths are compiled into the binary. On 2026-10-09 the framework was
rebuilt from the release assets this way (iPhoneOS 27.0 SDK, Apple clang
21.0.0) and compared with the shipped device slice: the exported symbol set
and the size of the machine code (`__TEXT,__text`) are identical, and the
only differing instructions are address computations (`adrp`, `add` and
load or store offsets) that moved because the embedded path strings have
different lengths.

## Replacing the framework in the app

A replacement must:

- be a dynamic framework named `VisionPlayerCoreFFmpegRuntime.framework` with
  install name `@rpath/VisionPlayerCoreFFmpegRuntime.framework/VisionPlayerCoreFFmpegRuntime`;
- be built for arm64 iOS with a deployment target of iOS 17.0 or lower (the
  app's own target);
- export every symbol in `records/app-imports-from-VisionPlayerCoreFFmpegRuntime.txt`
  with the same C ABI. That means the same library major versions (libavformat
  62, libavcodec 62, libavutil 60, libswresample 6, libswscale 9, libbluray
  1.4 with our overlay interface version 3) and the function
  `bd_select_hdmv_menu_button` that our libbluray change adds.

Put it in place of `Frameworks/VisionPlayerCoreFFmpegRuntime.framework`, then
sign the framework and the app again with your own certificate and a
provisioning profile that includes your device, and install with Xcode or
`xcrun devicectl`.

What iOS allows: iOS runs only code signed by Apple or by a developer
certificate whose provisioning profile includes the device. Copies of the app
installed from the App Store are encrypted and signed by Apple, so a framework
cannot be replaced inside an App Store installation on an unmodified device.
The replacement steps above work only for a copy of the app that you are able
to sign and install yourself.

## What we could not pin

- The shipped binary was built from two temporary build directories: FFmpeg
  and libbluray from one, dav1d and the final FFmpeg configure from another
  (the paths are visible in the config records). Both directories, their build
  logs and the meson configure records are gone. The configure records in
  `build/Packages/vision-player-core/Artifacts/BuildProvenance/` are kept.
- The revision of the build scripts that ran is not recorded separately. The
  copies here are from the app repository at commit `074e2f5`. Git history
  shows the scripts were last changed in the commit that added this runtime
  binary (2026-09-30); a later commit that day changed only the privacy
  manifest check in `audit-ios-ffmpeg-runtime.py` and the lock's manifest
  hashes.
- The rebuild described under "Rebuilding" nevertheless matches the shipped
  binary apart from the embedded build paths and the addresses they shift.
- All four sources are pinned exactly (archive hash or git commit), and the
  patches match the hashes recorded at build time
  (`BuildProvenance/ffmpeg-patch-sha256.txt`, and the libbluray patch hash in
  `BUILD-PROVENANCE.md`).

## 中文说明

本目录和同名 Release 是 Nsurator iPhone/iPad 1.0.1（101）中
`VisionPlayerCoreFFmpegRuntime.framework`（动态链接框架）的对应源码。框架里只有
FFmpeg 8.1、libbluray 1.4.1、libudfread（1.2.0 之后 3 个提交）和 dav1d 1.5.4，
不含应用代码。

- 我们改过 FFmpeg（7 个补丁）和 libbluray（3 处修改），修改说明和日期见
  `ffmpeg/CHANGES.md`、`libbluray/CHANGES.md`。libudfread 与 dav1d 未修改。
- Release 附件：上游源码包、补丁包、打完补丁后实际编译的源码树、构建脚本与记录、
  `SHA256SUMS`。
- 重新构建：`build/scripts/rebuild-ios-ffmpeg-runtime.sh <新的绝对路径>`；必须使用
  `base` 链接配置（默认的 `full` 会加入 FFmpeg 视为 GPL 的 DVD 库，应用没有使用）。
- 替换：做一个同名、同 install name、arm64、部署目标不高于 iOS 17.0 并导出
  `records/app-imports-from-VisionPlayerCoreFFmpegRuntime.txt` 中全部符号的动态框架，
  放进应用的 `Frameworks/`，再用你自己的证书和包含你设备的描述文件重新签名安装。
  iOS 只运行 Apple 或开发者证书签名的代码，App Store 安装的副本经过加密和 Apple 签名，
  因此无法在未改动的设备上替换 App Store 安装里的框架。
- 无法完全锁定的部分：当时的两个临时构建目录、构建日志和 meson 配置记录已不存在。
  2026-10-09 用 Release 附件重新构建并与发布版比对：导出符号集合和机器码大小完全
  一致，不同之处只有因编译进二进制的构建路径长度不同而改变的地址计算指令，因此
  二进制哈希不同。
