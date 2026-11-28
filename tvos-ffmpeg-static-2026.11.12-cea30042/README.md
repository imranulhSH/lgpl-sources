# Apple TV app: FFmpeg libraries built 2026-11-12 (static)

Release tag: `tvos-ffmpeg-static-2026.11.12-cea30042`

This folder and its release are the corresponding source for the FFmpeg,
libbluray, libudfread and dav1d code inside Nsuve for Apple TV.

## Which app builds use it

Nsuve for Apple TV, from its first distributed build. No build has been
distributed yet; the version and build number are added here when one ships.
The app links the libraries of the shared player core's tvOS build of
2026-11-12 (core commit `2e5da9da`; `build/nsurator-player-core-2e5da9d/`
here holds the recipe).

The libraries are linked **statically** into the app's executable,
`NsuratorTV.app/NsuratorTV` (the app is named Nsuve on the device): the eight
static libraries `libavformat`, `libavcodec`, `libavutil`, `libavfilter`,
`libswresample`, `libswscale`, `libbluray` (which contains libudfread) and
`libdav1d`, for arm64 Apple TV devices (`appletvos-arm64`). Their SHA-256
values are in `records/static-libraries-appletvos-arm64.sha256`; the tag ends
with the first eight digits of that file's own SHA-256. The same recipe also
builds a simulator slice (`appletvsimulator-arm64`), which is used only for
development and is never distributed.

The Apple TV app contains no libsmb2 and no AMSMB2: its SMB client is
SMBClient 0.3.1 (MIT licence), so the release
`ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6` does not apply to it.

## Components

| Component | Licence | Upstream archive (attached unchanged) | SHA-256 | Our changes |
|---|---|---|---|---|
| FFmpeg 8.1.2 | LGPL-2.1-or-later | https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz | `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c` | 15 patches, see `ffmpeg/CHANGES.md` |
| libbluray 1.4.1 | LGPL-2.1-or-later | https://code.videolan.org/videolan/libbluray/-/archive/1.4.1/libbluray-1.4.1.tar.gz | `e22381a313a231d94ddf9180564b36d803f33bdfc7c0b53c03868bc43e5d163d` | 4 patches, see `libbluray/CHANGES.md` |
| libudfread 1.2.0 | LGPL-2.1-or-later | https://code.videolan.org/videolan/libudfread/-/archive/1.2.0/libudfread-1.2.0.tar.gz | `adcce1190925f9d35a477757c5e3f0e221315d14d3d45b4ae62540ea0925f877` | none |
| dav1d 1.5.3 | BSD-2-Clause | https://code.videolan.org/videolan/dav1d/-/archive/1.5.3/dav1d-1.5.3.tar.gz | `cbe212b02faf8c6eed5b6d55ef8a6e363aaab83f15112e960701a9c3df813686` | none |

These are the same upstream archives as the iPhone/iPad, Mac and Apple Vision
Pro releases. The nineteen patches are the shared player core's at commit
`2e5da9da`. Eighteen of them are, byte for byte, the ones of the same names in
`ios-ffmpeg-runtime-2026.11.09.1-6e09d2b2`; the nineteenth,
`ffmpeg-hls-timeline-epochs.patch`, is in that release too, and here five of
its lines differ: at the end of a finished HLS playlist, media that stops before
the sum of the playlist's `EXTINF` durations is accepted (`ffmpeg/CHANGES.md`
0011). Against the Apple Vision Pro release
`visionos-ffmpeg-static-2026.11.12-10903474`: seventeen are the same byte for
byte, the HLS timeline patch differs in the same lines,
`ffmpeg-vobsub-host-io-inheritance.patch` is here and not there, and that
release's `ffmpeg-videotoolbox-visionos.patch`, which is only for visionOS, is
not here. No patch is in this release alone.

## Build configuration

- Recipe: `build/nsurator-player-core-2e5da9d/scripts/build-tvos-ffmpeg-runtime.sh`,
  with the source lock `Config/tvos-ffmpeg-sources.json` beside it (the shared
  player core's files at commit `2e5da9da31164e0155f9b142ab996aeb4ef35cbe`).
  It runs `prepare-tvos-ffmpeg-sources.py`, then `build-ffmpeg-apple.sh` for
  dav1d, libbluray and FFmpeg (`build-ffmpeg-visionos.sh` is, whatever its
  name, the core's one build script for every Apple platform, and
  `apply-ffmpeg-source-patches.sh` applies the FFmpeg patches), then packages
  and checks the result. The build set
  `NSURATOR_PLAYER_CORE_PKG_CONFIG=/opt/homebrew/bin/pkg-config`.
- FFmpeg configure line: `records/configure/ffmpeg-appletvos-arm64-configure.txt`
  (full record: `ffmpeg-appletvos-arm64-config.mak`; the simulator slice's
  records are beside them and differ in SDK and target). The `base` link
  profile, static: `--enable-static --disable-shared --enable-pic
  --disable-programs --disable-doc --disable-debug --disable-avdevice
  --disable-devices --enable-avcodec --enable-avformat --enable-avutil
  --enable-swresample --enable-swscale --enable-libbluray --enable-videotoolbox
  --enable-libdav1d --disable-network`, plus `--enable-cross-compile
  --target-os=darwin --arch=arm64` and `-target arm64-apple-tvos17.0
  -fembed-bitcode -fPIC` compiler flags. GPL, nonfree and version3 are off
  (`!CONFIG_GPL`, `!CONFIG_NONFREE`, `!CONFIG_VERSION3` in the record); the
  libraries report "LGPL version 2.1 or later". No network protocol and no TLS
  is compiled: the app reads files through its own I/O.
- The line names directories: the install prefix and the dependency paths
  under `/tmp/nsurator-tvos-core-cbc3434a0d54`, Xcode's compiler and SDK, and
  `/opt/homebrew/bin/pkg-config`. That `/tmp` directory is a link the build
  script makes to its work directory, named after the start of the SHA-256 of
  the work directory's path. FFmpeg compiles the line into each of its
  libraries.
- In the meson records and the logs, `$WORK` stands for the build's work
  directory (`.build/tvos-runtime` in the player core's checkout) and `$TOOLING`
  for the Python environment that held meson and ninja.
- libbluray: meson, static, release; tools, devtools, examples and docs off;
  `-Dbdj_jar=disabled -Dfreetype=disabled -Dfontconfig=disabled
  -Dlibxml2=disabled -Dembed_udfread=true -Dforce_fallback_for=libudfread`
  (`records/meson/`).
- dav1d: meson, static, release; tools, tests, examples and docs off.
- Toolchain: `records/toolchain.txt` and
  `records/artifact/TVOS-BUILD-EVIDENCE.json` (Xcode 27.1, tvOS 27.0 SDK,
  Apple clang 21.0.0 (clang-2100.3.34.2), target `arm64-apple-tvos17.0`;
  meson 1.12.1, ninja 1.13.2).

## Folder contents

| Path | What it is |
|---|---|
| `ffmpeg/patches/`, `libbluray/patches/` | Our patches, numbered in the order they are applied |
| `ffmpeg/CHANGES.md`, `libbluray/CHANGES.md` | Dated change notices |
| `libudfread/`, `dav1d/` | Licences and source notes (no changes) |
| `*/COPYING*`, `ffmpeg/LICENSE.md` | Licence texts taken from the upstream sources |
| `build/nsurator-player-core-2e5da9d/` | The player core's build scripts for this recipe, its source lock and its patch directory, in its layout |
| `reconstruct.py` | Unpacks the archives, applies the patches and checks every source file (see below) |
| `records/source-manifest.json` | The SHA-256 of each of the 11,443 source files the libraries were compiled from, and of the sixteen libraries |
| `records/` | The configure and meson records, the build's logs, the toolchain, the artifact's own records, the eight libraries' SHA-256 values and how they were checked (`PROVENANCE.md`) |
| `release-assets.sha256` | SHA-256 of every file attached to the release |

## Getting the sources the libraries were built from

`tvos-ffmpeg-static-2026.11.12-cea30042-patched-sources.tar.xz` holds the four
trees after patching (`sources/ffmpeg-8.1.2`, `sources/libbluray-1.4.1` with
libudfread in `contrib/libudfread`, `sources/libudfread-1.2.0`,
`sources/dav1d-1.5.3`). To make them yourself from the upstream archives and
the patches, and to check them:

```sh
mkdir work && cd work
tar -xzf /path/to/tvos-ffmpeg-static-2026.11.12-cea30042-build-scripts-and-records.tar.gz --strip-components=1
mkdir archives
cp /path/to/ffmpeg-8.1.2.tar.xz /path/to/libbluray-1.4.1.tar.gz \
   /path/to/libudfread-1.2.0.tar.gz /path/to/dav1d-1.5.3.tar.gz archives/
python3 reconstruct.py archives /absolute/path/to/a/new/directory
```

`reconstruct.py` needs Python 3.12 or later and `patch`. It downloads nothing
and compiles nothing. It checks every archive's SHA-256, unpacks the four,
copies libudfread into libbluray's `contrib/libudfread`, applies the patches of
`ffmpeg/patches/` and `libbluray/patches/` in numeric order with zero fuzz, and
compares the SHA-256 of every resulting file with `records/source-manifest.json`,
the list the player core's packaging script made from the trees the libraries
were compiled from. It prints
`{"verified": true, "components": 4, "sourceFiles": 11443, "patchesApplied": 19}`
and leaves the trees in `.build/tvos-runtime/sources/` of the new directory,
the archives in `.build/tvos-runtime/archives/`, and the build scripts beside
them (`scripts/`, `Config/`), which is the layout the scripts expect.

## Rebuilding the libraries

You need a Mac with Xcode (these libraries were built with Xcode 27.1 and its
tvOS 27.0 SDK), meson, ninja, pkg-config, git, and Python 3.12 or later as
`python3` on your `PATH` (the build scripts call `python3`). In the directory
`reconstruct.py` made:

```sh
cd /absolute/path/to/a/new/directory
printf '.build\n' > .gitignore
git init -q . && git add -A && git commit -q -m "release files"
NSURATOR_PLAYER_CORE_PKG_CONFIG=/opt/homebrew/bin/pkg-config \
NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES=appletvos-arm64 \
  bash scripts/build-tvos-ffmpeg-runtime.sh
```

The script checks every archive's SHA-256 against the lock (it downloads an
archive only when it is missing, and `reconstruct.py` has put all four in
place), finds the patches already applied, builds dav1d, libbluray and FFmpeg,
and packages the result. The six FFmpeg libraries end up in
`.build/tvos-runtime/artifact/install/appletvos-arm64/lib` and `libbluray.a`
and `libdav1d.a` in `.build/tvos-runtime/artifact/dependencies/appletvos-arm64/lib`.
The directory has to be a git repository because the script's last steps
record the commit it was run from (`write-tvos-build-evidence.py`).

## What was checked, and what was not

- **Checked: the sources.** The reconstruction above was run on this release's
  files as published, and all 11,443 files match the trees the libraries were
  compiled from.
- **Checked: which libraries.** The eight SHA-256 values in
  `records/static-libraries-appletvos-arm64.sha256` are those of the libraries
  the app's own notices manifest records as linked.
- **Not checked: a rebuild.** The libraries have not been built again from
  this release's files, so the commands under "Rebuilding the libraries" are the
  recipe as its scripts read, not a tested run, and we do not claim that a
  rebuild gives the same bytes. Two things are known to differ:
  - FFmpeg compiles its configure line into each of its six libraries, and
    the line holds `/tmp/nsurator-tvos-core-cbc3434a0d54`. The build script
    derives those twelve digits from the path of the directory it runs in, so a
    build in any other directory gets other digits. `libavcodec.a` holds the
    same alias in ten more strings (the file names two headers'
    assertions print).
  - `libdav1d.a` and `libbluray.a` are made by meson's `ar`, which writes each
    member's date and the builder's numeric user and group ids into the
    archive. Their SHA-256 values change in every rebuild; compare their
    members instead (`ar -x`).
- **Not checked: relinking the app** with rebuilt libraries.
- The libraries contain no home directory of the build machine. Apart from the
  alias above they name Xcode's compiler and tvOS SDK and
  `/opt/homebrew/bin/pkg-config` (`records/PROVENANCE.md`).

## Replacing the libraries in the app

The app links these libraries statically. To use modified libraries, the app's
executable must be linked again with them, which needs the app's own object
files. **This repository does not contain them.** The Nsurator support page
(https://www.nsurator.com/support.html#oss) explains how to ask for the
materials needed to relink.

What tvOS allows: like iOS, it runs only code signed by Apple or by a developer
certificate whose provisioning profile includes the device. Copies of the app
installed from the App Store are encrypted and signed by Apple, so a relinked
executable runs only in a copy of the app that you sign and install yourself.

## What we could not pin

- A byte-for-byte rebuild, for the two reasons above.
- The records do not hold the version of `pkg-config` or the build number of
  the tvOS SDK.

## 中文说明

本目录和同名 Release 是 Nsuve Apple TV 版中 FFmpeg 8.1.2、
libbluray 1.4.1、libudfread 1.2.0、dav1d 1.5.3 的对应源码。

- 适用版本：Apple TV 版从第一个对外发布的构建起使用这套库；目前还没有对外发布过，
  发布时在这里补上版本号和构建号。应用链接的是共用播放内核的 tvOS 构建配方在
  2026-11-12、内核提交 `2e5da9da` 上构建出的库（配方在 `build/nsurator-player-core-2e5da9d/`）。
- 这些库**静态链接**进应用主程序 `NsuratorTV.app/NsuratorTV`（在设备上叫 Nsuve），共 8 个
  静态库，SHA-256 见 `records/static-libraries-appletvos-arm64.sha256`；标签末尾的 8 位
  就是这个文件自身 SHA-256 的前 8 位。模拟器切片只用于开发，从不对外发布。
- Apple TV 版不含 libsmb2 和 AMSMB2：它的 SMB 客户端是 SMBClient 0.3.1（MIT 许可），
  所以 `ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6` 与它无关。
- 我们改过 FFmpeg（15 个补丁）和 libbluray（4 个补丁），修改说明和日期见
  `ffmpeg/CHANGES.md`、`libbluray/CHANGES.md`。19 个补丁都是共用播放内核提交 `2e5da9da`
  的补丁：其中 18 个与 `ios-ffmpeg-runtime-2026.11.09.1-6e09d2b2` 中同名的补丁
  逐字节相同；第 19 个 `ffmpeg-hls-timeline-epochs.patch` 在那一版里也有，这里有 5 行
  不同：已结束的 HLS 播放列表播到末尾时，媒体比各段 `EXTINF` 时长之和早结束也接受。
  与 Apple Vision Pro 的 `visionos-ffmpeg-static-2026.11.12-10903474` 相比：17 个逐字节
  相同，HLS 时间线补丁同样是这几行不同，这里多一个
  `ffmpeg-vobsub-host-io-inheritance.patch`，没有那一版只用于 visionOS 的
  `ffmpeg-videotoolbox-visionos.patch`。没有只在本 Release 里出现的补丁。构建用了
  `--disable-network`，网络协议相关的文件不会被编译。
- 取得构建所用的源码：`tvos-ffmpeg-static-2026.11.12-cea30042-patched-sources.tar.xz`
  是打完补丁后的四棵源码树。也可以自己还原并核对：按上面的命令解开构建脚本包，把四个上游源码包放进
  `archives/`，运行 `python3 reconstruct.py archives <新目录>`（需要 Python 3.12 或更新
  版本和 `patch`，不下载、不编译）。它校验源码包、解包、按编号零偏差打补丁，再把
  11,443 个文件逐个与 `records/source-manifest.json` 里的 SHA-256 核对。
- 重新构建：在还原出的目录里按上面的命令运行 `scripts/build-tvos-ffmpeg-runtime.sh`
  （需要装有 Xcode 的 Mac、meson、ninja、pkg-config、git，以及 `PATH` 上的 `python3` 是
  Python 3.12 或更新版本）。
- 核对过的：源码（用本 Release 对外发布的文件还原，11,443 个文件全部一致）；8 个库的
  SHA-256 与应用自己的第三方声明清单里记录的链接输入一致。
- **没有核对过的**：没有用本 Release 的文件把库重新编一遍，所以上面的构建命令是照脚本
  写的，不是实测过的；我们也不声称重建能得到逐字节相同的库。已知有两处会不同：FFmpeg
  把配置参数编进它的 6 个库，里面有 `/tmp/nsurator-tvos-core-cbc3434a0d54`，这 12 位是
  构建脚本按所在目录路径算出来的，换个目录就不同（`libavcodec.a` 另有 10 处断言用的
  文件名带这个路径）；meson 打包的 `libdav1d.a`、`libbluray.a` 会把每个成员的日期和构建者的
  用户号、组号写进归档，每次重建 SHA-256 都会变，比对时请先 `ar -x` 解开再比成员。
  也没有用重建的库重新链接过应用。
- 库里不含构建机器的家目录；除上面那个临时路径外，只有 Xcode 的编译器和 tvOS SDK 路径、
  `/opt/homebrew/bin/pkg-config`。记录中的 `$WORK`、`$TOOLING` 分别代表构建工作目录和放
  meson、ninja 的 Python 环境。
- 替换：由于是静态链接，需要用应用自己的目标文件重新链接主程序。**本仓库不包含这些
  目标文件**，获取方式见 https://www.nsurator.com/support.html#oss 。tvOS 和 iOS 一样只运行
  Apple 或包含该设备的开发者证书签名的代码，重新链接的主程序只能用在你自己签名安装的
  副本里。
- 无法锁定的部分：逐字节重建（原因见上）；记录里没有 `pkg-config` 的版本和 tvOS SDK
  的构建号。
