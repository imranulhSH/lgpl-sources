# Apple Vision Pro app: FFmpeg libraries built 2026-10-20 (static)

Release tag: `visionos-ffmpeg-static-2026.10.20-5d1d94b7`

This folder and its release are the corresponding source for the FFmpeg,
libbluray, libudfread and dav1d code inside Nsuve for Apple Vision Pro.

## Which app builds use it

Nsuve for Apple Vision Pro, from its first distributed build. No build has been
distributed yet; the version and build number are added here when one ships.
The app's source pins the recipe in `build/nsurator-visionos-native/` from commit
`17351ea` (2026-10-21) on, unchanged at commit `d81c336` (2026-11-10),
and its builds link the libraries that recipe made on 2026-10-20.

The libraries are linked **statically** into the app's executable,
`NsuratorVision.app/NsuratorVision` (the app is named Nsuve on the device): the
eight static libraries `libavformat`, `libavcodec`, `libavutil`, `libavfilter`,
`libswresample`, `libswscale`, `libbluray` (which contains libudfread) and
`libdav1d`, for arm64 visionOS devices (`xros-arm64`). Their SHA-256 values are
in `records/static-libraries-xros-arm64.sha256`; the tag ends with the first
eight digits of that file's own SHA-256. The same recipe also builds a simulator
slice (`xrsimulator-arm64`), which is used only for development and is never
distributed.

The app's SMB support, AMSMB2 and libsmb2, is a separate dynamic framework
(`AMSMB2.framework`) built from the same sources and patches as the iPhone's,
byte for byte: see the release `ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6`.

## Components

| Component | Licence | Upstream archive (attached unchanged) | SHA-256 | Our changes |
|---|---|---|---|---|
| FFmpeg 8.1.2 | LGPL-2.1-or-later | https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz | `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c` | 13 patches, see `ffmpeg/CHANGES.md` |
| libbluray 1.4.1 | LGPL-2.1-or-later | https://code.videolan.org/videolan/libbluray/-/archive/1.4.1/libbluray-1.4.1.tar.gz | `e22381a313a231d94ddf9180564b36d803f33bdfc7c0b53c03868bc43e5d163d` | 4 patches, see `libbluray/CHANGES.md` |
| libudfread 1.2.0 | LGPL-2.1-or-later | https://code.videolan.org/videolan/libudfread/-/archive/1.2.0/libudfread-1.2.0.tar.gz | `adcce1190925f9d35a477757c5e3f0e221315d14d3d45b4ae62540ea0925f877` | none |
| dav1d 1.5.3 | BSD-2-Clause | https://code.videolan.org/videolan/dav1d/-/archive/1.5.3/dav1d-1.5.3.tar.gz | `cbe212b02faf8c6eed5b6d55ef8a6e363aaab83f15112e960701a9c3df813686` | none |

These are the same upstream archives as the iPhone/iPad and Mac releases. Sixteen
of the seventeen patches are, byte for byte, the ones of the same names in
`ios-ffmpeg-runtime-2026.11.09.1-6e09d2b2`; the seventeenth,
`ffmpeg-videotoolbox-visionos.patch`, is new here: it makes FFmpeg's VideoToolbox
code build and work on visionOS.

## Build configuration

- Recipe: `build/nsurator-visionos-native/scripts/build_ffmpeg_visionos.sh`, with
  the source lock `scripts/ffmpeg/sources.lock.json` and the patch series
  `scripts/ffmpeg/patches/series` next to it (the app repository's files,
  unchanged since commit `17351ea`).
- FFmpeg configure line: `records/configure/ffmpeg-xros-arm64-configure.txt`
  (full record: `ffmpeg-xros-arm64-config.mak`). The `base` link profile,
  static: `--enable-static --disable-shared --enable-pic --disable-programs
  --disable-doc --disable-debug --disable-avdevice --disable-devices
  --enable-avcodec --enable-avformat --enable-avutil --enable-swresample
  --enable-swscale --enable-libbluray --enable-videotoolbox --enable-libdav1d
  --disable-network`, plus `--prefix`, `--cc`, `--sysroot`, `--pkg-config` and
  `-target arm64-apple-xros27.0` compiler and linker flags. GPL, nonfree and
  version3 are off (`!CONFIG_GPL`, `!CONFIG_NONFREE`, `!CONFIG_VERSION3` in the
  record); the libraries report "LGPL version 2.1 or later". No network protocol
  and no TLS is compiled: the app reads files through its own I/O.
- In the records, `$WORK` stands for the build's work directory and `$TOOLING`
  for the Python environment that held meson, ninja and pkg-config.
- libbluray: meson, static, release; tools, devtools, examples and docs off;
  `-Dbdj_jar=disabled -Dfreetype=disabled -Dfontconfig=disabled
  -Dlibxml2=disabled -Dembed_udfread=true -Dforce_fallback_for=libudfread`
  (`records/meson/`).
- dav1d: meson, static, release; tools, tests, examples and docs off.
- Toolchain: Xcode 27.0 (27A266a), visionOS 27.0 SDK, Apple clang 21.0.0
  (clang-2100.3.34.2), target `arm64-apple-xros27.0`; meson 1.12.1, ninja
  1.13.2 (`records/toolchain.txt`, `records/BUILD-INFO-xros-arm64.txt`).

## Folder contents

| Path | What it is |
|---|---|
| `ffmpeg/patches/`, `libbluray/patches/` | Our patches, numbered in the order they are applied |
| `ffmpeg/CHANGES.md`, `libbluray/CHANGES.md` | Dated change notices |
| `libudfread/`, `dav1d/` | Licences and source notes (no changes) |
| `*/COPYING*`, `ffmpeg/LICENSE.md` | Licence texts taken from the upstream sources |
| `build/nsurator-visionos-native/scripts/` | The app repository's build script, source lock, probe program and patch series, in its layout |
| `records/` | The configure and meson records, the toolchain, the eight libraries' SHA-256 values and how they were checked (`PROVENANCE.md`) |
| `release-assets.sha256` | SHA-256 of every file attached to the release |

## Rebuilding the libraries

You need a Mac with Xcode (the libraries were built with Xcode 27.0 and its
visionOS 27.0 SDK), meson, ninja, pkg-config and python3. The directory must not
contain spaces.

```sh
mkdir /absolute/path/without/spaces && cd /absolute/path/without/spaces
tar -xzf /path/to/visionos-ffmpeg-static-2026.10.20-5d1d94b7-build-scripts-and-records.tar.gz --strip-components=1
mkdir archives
cp /path/to/ffmpeg-8.1.2.tar.xz /path/to/libbluray-1.4.1.tar.gz \
   /path/to/libudfread-1.2.0.tar.gz /path/to/dav1d-1.5.3.tar.gz archives/
NV_FFMPEG_ARCHIVES="$PWD/archives" NV_FFMPEG_SLICES=xros-arm64 \
  build/nsurator-visionos-native/scripts/build_ffmpeg_visionos.sh
```

The script checks every archive's SHA-256 against the lock, unpacks them,
copies libudfread into libbluray's `contrib/libudfread`, applies the patches in
the order of `series`, builds dav1d, libbluray and FFmpeg, and links a small
probe program (`scripts/ffmpeg/probe.c`) against the result. It finds meson,
ninja and pkg-config in the directory `NV_FFMPEG_TOOLING` names, or on `PATH`.
The static libraries end up in
`build/nsurator-visionos-native/artifacts/ffmpeg/xros-arm64/lib`. It never
downloads anything. Two steps of its check need our other repositories or a
running simulator and are skipped without them: the link check of our player's
FFmpeg shim, and running the probe in a booted visionOS simulator.

`visionos-ffmpeg-static-2026.10.20-5d1d94b7-patched-sources.tar.xz` holds the four trees after patching
(`sources/ffmpeg-8.1.2`, `sources/libbluray-1.4.1` with libudfread in
`contrib/libudfread`, `sources/libudfread-1.2.0`, `sources/dav1d-1.5.3`), for
reading or for building by hand with the commands in the records.

## Replacing the libraries in the app

The app links these libraries statically. To use modified libraries, the app's
executable must be linked again with them, which needs the app's own object
files. **This repository does not contain them.** In the app, Settings › About ›
Open-Source Licenses › Source Code and Relinking Materials (设置 › 关于 › 开源许可 ›
源代码和重新链接材料) says how to ask for the materials needed to relink; see also
https://www.nsurator.com/support.html#oss.

What visionOS allows: like iOS, it runs only code signed by Apple or by a
developer certificate whose provisioning profile includes the device. Copies of
the app installed from the App Store are encrypted and signed by Apple, so a
relinked executable runs only in a copy of the app that you sign and install
yourself.

## What we could not pin

- The libraries do not rebuild byte for byte. Rebuilt on 2026-11-10 from this
  release's files with the commands above, in another directory (Xcode 27.1,
  visionOS 27.0 SDK), the build and its checks passed, but all eight libraries
  differ from the shipped ones, at least in the build paths compiled into them
  (FFmpeg also keeps its configure line, with those paths, in `libavutil`).
  What was checked instead is in `records/PROVENANCE.md`: the patched trees
  equal, file for file, the trees the shipped libraries were built from, and
  the app was linked with libraries of exactly the SHA-256 values in the
  records.
- The build did not log pkg-config's version.

## 中文说明

本目录和同名 Release 是 Nsuve Apple Vision Pro 版中 FFmpeg 8.1.2、
libbluray 1.4.1、libudfread 1.2.0、dav1d 1.5.3 的对应源码。

- 适用版本：Apple Vision Pro 版从第一个对外发布的构建起使用这套库；目前还没有对外
  发布过，发布时在这里补上版本号和构建号。应用源码从提交 `17351ea`（2026-10-21）
  起固定使用 `build/nsurator-visionos-native/` 里的构建配方，到 `d81c336`（2026-11-10）
  没有变，构建时链接的是这套配方 2026-10-20 构建出的库。
- 这些库**静态链接**进应用主程序 `NsuratorVision.app/NsuratorVision`（在设备上叫
  Nsuve），共 8 个静态库，SHA-256 见 `records/static-libraries-xros-arm64.sha256`；
  标签末尾的 8 位就是这个文件自身 SHA-256 的前 8 位。模拟器切片只用于开发，从不对外发布。
- 我们改过 FFmpeg（13 个补丁）和 libbluray（4 个补丁），修改说明和日期见
  `ffmpeg/CHANGES.md`、`libbluray/CHANGES.md`。其中 16 个补丁与
  `ios-ffmpeg-runtime-2026.11.09.1-6e09d2b2` 中同名的补丁逐字节相同；
  `ffmpeg-videotoolbox-visionos.patch` 是 visionOS 新加的，让 FFmpeg 的 VideoToolbox
  代码能在 visionOS 上编译和使用。构建用了 `--disable-network`，网络协议相关的文件
  不会被编译。
- SMB 支持（AMSMB2 和 libsmb2）是单独的动态框架 `AMSMB2.framework`，源码和补丁与
  iPhone 版逐字节相同，见 `ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6`。
- 重新构建：按上面的命令把构建脚本包解到一个路径不含空格的新目录，把四个上游源码包
  放进 `archives/`，运行 `build_ffmpeg_visionos.sh`；脚本会校验源码包、打补丁并构建，
  不会下载任何东西。记录中的 `$WORK`、`$TOOLING` 分别代表构建工作目录和放 meson、
  ninja、pkg-config 的 Python 环境。
- 替换：由于是静态链接，需要用应用自己的目标文件重新链接主程序。**本仓库不包含这些
  目标文件**，获取方式见应用里的 设置 › 关于 › 开源许可 › 源代码和重新链接材料，以及
  https://www.nsurator.com/support.html#oss 。visionOS 和 iOS 一样只运行 Apple 或包含
  该设备的开发者证书签名的代码，重新链接的主程序只能用在你自己签名安装的副本里。
- 无法锁定的部分：库不能逐字节重现。2026-11-10 按上面的命令在另一个目录用本 Release
  的文件重建（Xcode 27.1，visionOS 27.0 SDK），构建和检查都通过，但 8 个库都与发布的
  不同，至少编进去的构建路径不同（FFmpeg 还把带路径的配置参数编进了 `libavutil`）。
  能确认的是：打完补丁的源码树与构建所用的逐个文件相同，应用链接的库的 SHA-256 与
  记录一致，见 `records/PROVENANCE.md`。构建没有记录 pkg-config 的版本。
