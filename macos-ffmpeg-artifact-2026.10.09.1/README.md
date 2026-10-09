# Mac app: FFmpeg artifact 2026.10.09.1

Release tag: `macos-ffmpeg-artifact-2026.10.09.1`

This folder and its release are the corresponding source for the FFmpeg,
libbluray, libudfread and dav1d code inside Nsurator for Mac's player, in the
builds that link them **dynamically**.

## Which app builds use it

Nsurator for Mac builds made from the app's source at or after commit
`3fd9615e`, which pinned artifact 2026.10.09.1 (player core `ebfc8a0`, and from
the merge on `0d5c2fe`, which packages the framework with the same script).
The first Mac App Store version that uses it is the first one submitted after
5.9.17 (build 8); 5.9.17 (build 8) itself and every earlier distributed Mac
build (on or after 2026-09-24) used artifact 2026.09.24.1, linked statically,
whose release is
[`macos-ffmpeg-artifact-2026.09.24.1`](../macos-ffmpeg-artifact-2026.09.24.1/).

The libraries are in one framework inside the app:

- `Nsurator.app/Contents/Frameworks/NsuratorPlayerCoreFFmpegRuntime.framework`

and two executables load it:

- `Nsurator.app/Contents/MacOS/NsuratorNative`
- `Nsurator.app/Contents/XPCServices/NsuratorDecoderProbeHelper.xpc/Contents/MacOS/NsuratorDecoderProbeHelper`

The framework's install name is
`@rpath/NsuratorPlayerCoreFFmpegRuntime.framework/Versions/A/NsuratorPlayerCoreFFmpegRuntime`.
The app finds it through the rpath `@executable_path/../Frameworks` (the decoder
helper through `@executable_path/../../../../Frameworks`), and neither
executable contains a copy of the libraries.

## The libraries are the 2026.09.24.1 libraries

Artifact 2026.10.09.1 was not built from source again. It takes the eight
static libraries of artifact 2026.09.24.1, unchanged, and links them into the
framework:

| Library | SHA-256 (same in both artifacts) |
|---|---|
| `install/macosx-arm64/lib/libavcodec.a` | `d92be477f17fc8c52e51c3628ee161d02851141991267a1be7bae4d775f1b338` |
| `install/macosx-arm64/lib/libavfilter.a` | `b0a527e79bb59444f6e06d78818c6869ff08688f7a20d4f23dc0b67ecc245274` |
| `install/macosx-arm64/lib/libavformat.a` | `12283b83ff8500edea2f39824d69f230e383166f287be79d4236886ddebafd2d` |
| `install/macosx-arm64/lib/libavutil.a` | `ced8cb36d068d4b95eda72b31bccc56678a0cfe86642d1b2c49ab1b86e666caf` |
| `install/macosx-arm64/lib/libswresample.a` | `1c0c674eb1fc9b7c5f2f10448069e67b6f10213587264989ad6281d4493dcab0` |
| `install/macosx-arm64/lib/libswscale.a` | `1a46ce102e3530ee3b33f22175fb6fc63ca1f6d440587877764d88d48e42eb78` |
| `dependencies/macosx-arm64/lib/libbluray.a` (contains libudfread) | `cfced98757c3508edfee3408b0148a5fa9df36ed4455e843b6b19e940843909a` |
| `dependencies/macosx-arm64/lib/libdav1d.a` | `459048e458a2cb875590a925c8f62c2540d397ac358f727a91ba418cbb0de61a` |

So the sources, our patches and the build configuration are exactly those of
2026.09.24.1. They are repeated here so this release stands on its own.

## Components

| Component | Licence | Upstream archive | SHA-256 | Our changes |
|---|---|---|---|---|
| FFmpeg 8.1.2 | LGPL-2.1-or-later | https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz | `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c` | 7 patches, see `ffmpeg/CHANGES.md` |
| libbluray 1.4.1 | LGPL-2.1-or-later | https://code.videolan.org/videolan/libbluray/-/archive/1.4.1/libbluray-1.4.1.tar.gz | `e22381a313a231d94ddf9180564b36d803f33bdfc7c0b53c03868bc43e5d163d` | 3 patches, see `libbluray/CHANGES.md` |
| libudfread 1.2.0 | LGPL-2.1-or-later | https://code.videolan.org/videolan/libudfread/-/archive/1.2.0/libudfread-1.2.0.tar.gz | `adcce1190925f9d35a477757c5e3f0e221315d14d3d45b4ae62540ea0925f877` | none |
| dav1d 1.5.3 | BSD-2-Clause | https://code.videolan.org/videolan/dav1d/-/archive/1.5.3/dav1d-1.5.3.tar.gz | `cbe212b02faf8c6eed5b6d55ef8a6e363aaab83f15112e960701a9c3df813686` | none |

The release attaches the same upstream archives, and the same patch and
patched-source archives, as release 2026.09.24.1: byte for byte and under their
2026.09.24.1 names (`macos-ffmpeg-artifact-2026.09.24.1-patches.tar.gz`,
`macos-ffmpeg-artifact-2026.09.24.1-patched-sources.tar.xz`).
`release-assets.sha256` lists every attached file.

## The framework

| | |
|---|---|
| Name | `NsuratorPlayerCoreFFmpegRuntime.framework` (versioned: `Versions/A`, `Versions/Current`, no headers) |
| Install name | `@rpath/NsuratorPlayerCoreFFmpegRuntime.framework/Versions/A/NsuratorPlayerCoreFFmpegRuntime` |
| Binary SHA-256 (before signing) | `d6fe5a3e987b20b6bd255f3940e747bacb9576c9b3e417824b46c8e5632c1cff` |
| LC_UUID (signing keeps it) | `58BB2D7D-52C4-3BC0-9CD2-5C811162D69A` |
| Architecture, minimum macOS | arm64, 14.0 |
| Dependencies | system frameworks and libraries only (CoreFoundation, CoreMedia, CoreVideo, CoreServices, CoreImage, AppKit, OpenGL, AudioToolbox, VideoToolbox, DiskArbitration, libz, libbz2, libiconv) |

The app store copy of the binary differs from the SHA-256 above only by its
code signature; compare the UUID (`dwarfdump --uuid`) instead.

`records/framework/FRAMEWORK-RECORD.json` has the exact link command (with
paths relative to the artifact), the checksum of every input archive, the
checksum of the exported symbol list, and the compiler and linker versions.
The framework was built five times, in five different directories, and the
five binaries were identical.

## Folder contents

| Path | What it is |
|---|---|
| `ffmpeg/`, `libbluray/`, `libudfread/`, `dav1d/` | Patches, change notices and licence texts; identical to the 2026.09.24.1 folder |
| `build/nsurator-player-core-8c27b0c/scripts/` | The player core's library build scripts and patches at commit `8c27b0cdb1bf6981682fd182bce677fc5cc3a81e`, which built the eight libraries |
| `build/nsurator-player-core-ebfc8a0/scripts/` | The player core's scripts at commit `ebfc8a0f3dbb3d054a1054d8c530fa91d4e78d39`, which packaged the framework: `package-apple-ffmpeg-runtime-framework.sh` (the framework), `build-ffmpeg-apple.sh` / `build-ffmpeg-visionos.sh` (`--package-artifact-root` in framework mode) and `assemble-ffmpeg-artifact-release-packet.py` |
| `build/nsurator-macos-native/` | The Mac app repository's artifact script (`--repackage-from-artifact`), its helpers and the two locks at commit `3fd9615e`, which pinned this artifact |
| `records/framework/` | `FRAMEWORK-RECORD.json` |
| `records/artifact/` | Records shipped inside the artifact: provenance, manifest, relinking notes, relink-materials manifest |
| `records/app/` | The symbols the app executable and the decoder helper import from the framework (`*-imports.txt`), and the seven optional ones they look up at launch (`optional-imports.txt`) |
| `release-assets.sha256` | SHA-256 of every file attached to the release |

## Rebuilding the libraries

Exactly as for 2026.09.24.1 (see that folder's README): unpack this release's
`macos-ffmpeg-artifact-2026.10.09.1-build-scripts-and-records.tar.gz` and the
attached `macos-ffmpeg-artifact-2026.09.24.1-patched-sources.tar.xz` into one
new directory without spaces in its path, each with `--strip-components=1`,
then run `build/nsurator-player-core-8c27b0c/scripts/build-ffmpeg-apple.sh`
three times (dav1d, libbluray, FFmpeg) with
`NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE=base`,
`NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS="--enable-libdav1d --disable-network"`
and `NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES=libdav1d`. Keep `base`: the
`8c27b0c` scripts' default profile (`full`) adds DVD libraries that FFmpeg
treats as GPL. (From player core `ebfc8a0` on, `base` is the default.) The
libraries end up in `$work/ffmpeg-install/macosx-arm64/lib` and
`$work/dependencies/macosx-arm64/lib`.

## Building the framework

```sh
build/nsurator-player-core-ebfc8a0/scripts/package-apple-ffmpeg-runtime-framework.sh --build \
  --ffmpeg-prefix "$work/ffmpeg-install/macosx-arm64" \
  --dependency-prefix "$work/dependencies/macosx-arm64" \
  --output-dir "$work/frameworks/macosx-arm64"
```

It force-loads every static library of the two prefixes, unchanged, into
`NsuratorPlayerCoreFFmpegRuntime.framework`, checks the layout, install name,
architecture, minimum macOS, dependencies and the exports the app uses, and
writes `FRAMEWORK-RECORD.json` beside the framework. It needs Xcode and
pkg-config (it reads the libraries' `.pc` files for their system dependencies).
`--verify <framework>` repeats the checks on any framework. With the eight
libraries listed above and the toolchain in the record, the binary's SHA-256
is the one above.

## Replacing the libraries in the app

The app links the libraries dynamically, so you can replace them without the
app's object files:

1. Build the libraries (modified or not) and the framework as above. Keep the
   framework name and the install name, and keep the functions the app imports
   (`records/app/*-imports.txt` lists them; leaving the configure flags as they
   are keeps them all). The app also looks up seven optional functions at
   launch (`records/app/optional-imports.txt`, `avpriv_nsurator_*`), which
   later versions of our FFmpeg patches add; the libraries of this release do
   not have them, the app works without them, and a framework of yours that
   defines them is the one the app calls.
2. Replace `Nsurator.app/Contents/Frameworks/NsuratorPlayerCoreFFmpegRuntime.framework`
   with your framework.
3. Sign the app again, inner code first: the framework, then
   `Contents/XPCServices/NsuratorDecoderProbeHelper.xpc`, then the app. Either
   sign all three with one identity of your own, or sign them ad hoc (`-`) and
   give the app and the helper the entitlement
   `com.apple.security.cs.disable-library-validation`; an ad hoc signature has
   no Team ID, and without that entitlement the hardened runtime refuses to
   load a framework that is not signed by the app's own team. Leave out
   entitlements that need a provisioning profile
   (`com.apple.application-identifier`, `com.apple.developer.team-identifier`).
4. macOS may ask you to allow the change to the app under System Settings ›
   Privacy & Security › App Management.

A re-signed copy no longer carries the Mac App Store signature, so features
that depend on it (in-app purchases, and data containers and app groups tied
to the developer's team) may not work in that copy.

## What we could not pin

- The libraries' own build: see the 2026.09.24.1 README (the build's work
  directory is gone; meson and pkg-config versions were not recorded).
- The framework was linked with Apple clang 21.0.0 and the MacOSX 27.0 SDK
  (both recorded in `FRAMEWORK-RECORD.json`); another toolchain gives a
  working framework with a different checksum.

## 中文说明

本目录和同名 Release 是 Nsurator for Mac 播放核心中 FFmpeg 8.1.2、libbluray 1.4.1、
libudfread 1.2.0、dav1d 1.5.3 的对应源码，适用于以**动态链接**方式使用这些库的构建
（应用源码提交 `3fd9615e` 固定到 artifact 2026.10.09.1，即播放核心 `ebfc8a0`，合并后为
用同一脚本打包框架的 `0d5c2fe`；此提交及之后的构建都使用它）。第一个使用它的 Mac App Store
版本是 5.9.17（build 8）之后提交的第一个版本；5.9.17（build 8）本身及 2026-09-24 起分发的
更早构建以静态方式使用 artifact 2026.09.24.1。

- 这些库放在应用内的一个框架中：
  `Contents/Frameworks/NsuratorPlayerCoreFFmpegRuntime.framework`，应用主程序
  `NsuratorNative` 与解码辅助进程 `NsuratorDecoderProbeHelper` 通过 `@rpath`
  加载它，两个可执行文件里都不含这些库的副本。
- 2026.10.09.1 没有重新从源码构建：它把 2026.09.24.1 的 8 个静态库原样（SHA-256
  见上表）链接成框架。因此源码、我们的补丁和构建配置与 2026.09.24.1 完全相同；
  本目录重复收录，使本 Release 可独立使用。
- 框架：install name `@rpath/NsuratorPlayerCoreFFmpegRuntime.framework/Versions/A/NsuratorPlayerCoreFFmpegRuntime`，
  签名前 SHA-256 `d6fe5a3e…1cff`，LC_UUID `58BB2D7D-52C4-3BC0-9CD2-5C811162D69A`
  （签名不改变 UUID）。在五个不同目录各构建一次，五次结果完全相同。
- 重新构建库：与 2026.09.24.1 相同，用 `build/nsurator-player-core-8c27b0c/scripts/build-ffmpeg-apple.sh`
  运行三次，必须保持 `base` 链接配置。然后用
  `build/nsurator-player-core-ebfc8a0/scripts/package-apple-ffmpeg-runtime-framework.sh --build`
  生成框架（命令见上文）。
- 应用启动时还会查找七个可选函数（`avpriv_nsurator_*`，见 `records/app/optional-imports.txt`），
  它们来自我们较新版本的 FFmpeg 补丁；本 Release 的库没有这些函数，应用照常工作；
  如果你的框架定义了它们，应用就调用你的版本。
- 替换：用你构建的框架（保持框架名与 install name）替换应用内的同名框架，然后按
  “框架 → 解码辅助进程 → 应用”的顺序重新签名：三者用同一个身份签名，或者用
  ad hoc 签名并给应用和辅助进程加上 `com.apple.security.cs.disable-library-validation`
  权限；不要带需要描述文件的权限。macOS 可能会在“隐私与安全性 › App 管理”中请你
  允许这次修改。替换不需要应用的目标文件。
- 重新签名的副本不再带有 Mac App Store 签名，内购、与开发者团队绑定的数据容器和
  App Group 可能无法使用。
