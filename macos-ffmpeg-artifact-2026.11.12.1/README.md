# Mac app: FFmpeg artifact 2026.11.12.1

Release tag: `macos-ffmpeg-artifact-2026.11.12.1`

This folder and its release are the corresponding source for the FFmpeg,
libbluray, libudfread and dav1d code inside the player of Nsuve (formerly
Nsurator) for Mac, in the builds that carry artifact 2026.11.12.1.

## Which app builds use it

Mac builds made from the app's source that pins artifact 2026.11.12.1, from
the first build distributed with it (app commit `9311b660`, which pinned it with
player core `e4e032fe`; the version and the build number are added here when it
ships). The app's player core then moved to `49783275` and `fdba50b5` with the
same artifact: neither commit changes a patch or a build script, so those builds
load these same libraries. It replaces
artifact 2026.10.09.1, whose release is
[`macos-ffmpeg-artifact-2026.10.09.1`](../macos-ffmpeg-artifact-2026.10.09.1/);
builds that pin 2026.10.09.1 or 2026.09.24.1 keep their own releases.

The libraries are in one framework inside the app:

- `Nsuve.app/Contents/Frameworks/NsuratorPlayerCoreFFmpegRuntime.framework`

and two executables load it:

- `Nsuve.app/Contents/MacOS/Nsuve`
- `Nsuve.app/Contents/XPCServices/NsuveDecoderProbeHelper.xpc/Contents/MacOS/NsuveDecoderProbeHelper`

The framework's install name is
`@rpath/NsuratorPlayerCoreFFmpegRuntime.framework/Versions/A/NsuratorPlayerCoreFFmpegRuntime`.
The app finds it through the rpath `@executable_path/../Frameworks` (the decoder
helper through `@executable_path/../../../../Frameworks`), and neither
executable contains a copy of the libraries.

## Built from source

Artifact 2026.10.09.1 took the static libraries of 2026.09.24.1 unchanged.
Artifact 2026.11.12.1 does not: it was built from source on 2026-11-12, from the
four upstream archives below and our patches at player core
`e4e032fe04f9d64eacf4ba90ffa128e8d028fa31` (15 for FFmpeg and 4 for libbluray,
where 2026.09.24.1 had 7 and 3), by
`build/nsurator-macos-native/script/build_nsurator_player_core_ffmpeg_artifact.sh`
in the work root `/tmp/nsurator-npc-artifact-build-202611121`. The artifact
archive, `nsurator-player-core-ffmpeg-macosx-arm64-2026.11.12.1.tar.gz`
(SHA-256 `e3a22a00dd70bb70471aa1986e3246f6f250ffd7df32c7ca93e60e0b1f02f4ef`,
pinned by `build/nsurator-macos-native/Config/nsurator-player-core-ffmpeg-artifact.lock.json`),
holds the framework and the static libraries it was linked from:

| Library | SHA-256 |
|---|---|
| `install/macosx-arm64/lib/libavcodec.a` | `4ae7ef6d7537f8738a514ade875809690abe200a38f8405ad12674d2f2a57519` |
| `install/macosx-arm64/lib/libavfilter.a` | `c310d677bd561189cea49e781cb29071562e293a97cb0f2c64929391175545a8` |
| `install/macosx-arm64/lib/libavformat.a` | `6722ffd722ebb65faa29601661c95f0ea0e7e5c977ad0c91a003c33b81048915` |
| `install/macosx-arm64/lib/libavutil.a` | `33b1e6b5ff2f8a022bef459f42c41a18d468681f7cbed8a72e2bd54a89de4e63` |
| `install/macosx-arm64/lib/libswresample.a` | `55d903558c74e12c7d04690df13155caacc541bf193b6f4a7ed77b17f3aa0207` |
| `install/macosx-arm64/lib/libswscale.a` | `e40601f6140a33f0336d939e8d3f336e06f153b5ce578dac1a564069dd911de7` |
| `dependencies/macosx-arm64/lib/libbluray.a` (contains libudfread) | `efbd861f5ad0021f45a5ffd89b615f09cd4c5288a710046d843de4dd6742f3ab` |
| `dependencies/macosx-arm64/lib/libdav1d.a` | `4ba26d9aec7a107107900bcf2c3db169782e90200e7d7cbf436a5506cc398e76` |

## Components

| Component | Licence | Upstream archive | SHA-256 | Our changes |
|---|---|---|---|---|
| FFmpeg 8.1.2 | LGPL-2.1-or-later | https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz | `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c` | 15 patches (11 compiled), see `ffmpeg/CHANGES.md` |
| libbluray 1.4.1 | LGPL-2.1-or-later | https://code.videolan.org/videolan/libbluray/-/archive/1.4.1/libbluray-1.4.1.tar.gz | `e22381a313a231d94ddf9180564b36d803f33bdfc7c0b53c03868bc43e5d163d` | 4 patches, see `libbluray/CHANGES.md` |
| libudfread 1.2.0 | LGPL-2.1-or-later | https://code.videolan.org/videolan/libudfread/-/archive/1.2.0/libudfread-1.2.0.tar.gz | `adcce1190925f9d35a477757c5e3f0e221315d14d3d45b4ae62540ea0925f877` | none |
| dav1d 1.5.3 | BSD-2-Clause | https://code.videolan.org/videolan/dav1d/-/archive/1.5.3/dav1d-1.5.3.tar.gz | `cbe212b02faf8c6eed5b6d55ef8a6e363aaab83f15112e960701a9c3df813686` | none |

The release attaches the exact archives the build used. Their SHA-256 values
match the source lock
(`build/nsurator-macos-native/Config/nsurator-player-core-ffmpeg-sources.json`),
and they are byte for byte the archives attached to releases 2026.09.24.1 and
2026.10.09.1. The release also attaches our patches with their change notices
(`macos-ffmpeg-artifact-2026.11.12.1-patches.tar.gz`) and the four source trees
as the build compiled them (`macos-ffmpeg-artifact-2026.11.12.1-patched-sources.tar.xz`).
Applying `ffmpeg/patches/` and `libbluray/patches/` in numeric order to the
upstream archives, with libudfread copied into `libbluray-1.4.1/contrib/libudfread`,
gives exactly those trees (`patch` may leave `.orig` copies beside three of the
changed files; they are not part of the trees). `release-assets.sha256` lists
every attached file.

## Build configuration

- FFmpeg configure line (`records/configure/ffmpeg-macosx-arm64-configure.txt`;
  the full configure record is `ffmpeg-macosx-arm64-config.mak` beside it):
  `--enable-cross-compile --target-os=darwin --arch=arm64 --enable-static --disable-shared --enable-pic --disable-programs --disable-doc --disable-debug --disable-avdevice --disable-devices --enable-avcodec --enable-avformat --enable-avutil --enable-swresample --enable-swscale --enable-libbluray --enable-videotoolbox --enable-libdav1d --disable-network`,
  plus `--prefix`, `--cc`, `--sysroot`, `--pkg-config` and
  `-target arm64-apple-macos14.0` compiler and linker flags. The line recorded
  in `records/artifact/nsurator-player-core-ffmpeg-apple-manifest.json` ends
  with `--enable-npc-libbluray`; that word is a marker added by our player's
  capability report, not an FFmpeg configure option.
- Link profile `base`. GPL, nonfree and version3 are off (`!CONFIG_GPL`,
  `!CONFIG_NONFREE`, `!CONFIG_VERSION3` in the configure record), and the
  libraries report "LGPL version 2.1 or later". No network protocol is built.
- Toolchain (`records/toolchain.txt`): Xcode 27.1 (27A9275) with the MacOSX
  27.0 SDK, Apple clang 21.0.0 (clang-2100.3.34.2), ld-27037.1, meson 1.11.2,
  ninja 1.13.2, pkg-config 2.5.1; minimum macOS 14.0.
- libbluray: meson, static, release; tools, devtools, examples and docs off;
  `-Dbdj_jar=disabled -Dfreetype=disabled -Dfontconfig=disabled -Dlibxml2=disabled -Dembed_udfread=true -Dforce_fallback_for=libudfread`
  (`records/meson/`, with the cross file).
- dav1d: meson, static, release; tools, tests, examples and docs off
  (`records/meson/`, with the cross file).

## The framework

| | |
|---|---|
| Name | `NsuratorPlayerCoreFFmpegRuntime.framework` (versioned: `Versions/A`, `Versions/Current`, no headers; `Resources/` holds `Info.plist` and `PrivacyInfo.xcprivacy`) |
| Install name | `@rpath/NsuratorPlayerCoreFFmpegRuntime.framework/Versions/A/NsuratorPlayerCoreFFmpegRuntime` |
| Binary SHA-256 (before signing) | `01331bb2ac2378c3778d7c12b5bbf638229ef3d717340ecc5a2d999af1612f28` (23,586,080 bytes) |
| LC_UUID (signing keeps it) | `F1E2242D-967C-3D9C-B2D4-76E74F0F2D8C` |
| Architecture, minimum macOS | arm64, 14.0 |
| Exports | 7,349 symbols |
| Dependencies | system frameworks and libraries only (AppKit, AudioToolbox, CoreFoundation, CoreGraphics, CoreImage, CoreMedia, CoreServices, CoreVideo, DiskArbitration, Foundation, OpenGL, VideoToolbox, libSystem, libbz2, libiconv, libobjc, libz) |

The App Store copy of the binary differs from the SHA-256 above only by its
code signature; compare the UUID (`dwarfdump --uuid`) instead.

`records/framework/FRAMEWORK-RECORD.json` has the exact link command (with
paths relative to the artifact), the checksum of every input archive, the
checksum of the exported symbol list, and the compiler and linker versions.

## Folder contents

| Path | What it is |
|---|---|
| `ffmpeg/patches/`, `libbluray/patches/` | Our patches, numbered in the order they are applied |
| `ffmpeg/CHANGES.md`, `libbluray/CHANGES.md` | Dated change notices, and which changes are compiled |
| `libudfread/`, `dav1d/` | Licences and source notes (no changes) |
| `*/COPYING*`, `ffmpeg/LICENSE.md` | Licence texts taken from the upstream sources |
| `build/nsurator-player-core-e4e032f/scripts/` | The player core's scripts at commit `e4e032fe04f9d64eacf4ba90ffa128e8d028fa31`, which built the libraries and the framework: `build-ffmpeg-apple.sh` and `build-ffmpeg-visionos.sh` (dav1d, libbluray and FFmpeg, and `--package-artifact-root`), `apply-ffmpeg-source-patches.sh`, `package-apple-ffmpeg-runtime-framework.sh` (the framework) and `assemble-ffmpeg-artifact-release-packet.py`. `patches/` holds the 15 FFmpeg and 4 libbluray patches under the names the scripts use; the core's DVD-library patches, which this build does not use, are left out |
| `build/nsurator-macos-native/` | The Mac app repository's artifact build script, its helpers and the two locks that pin this artifact |
| `records/artifact/` | Records shipped inside the artifact, in its own layout: provenance (a copy of the source lock), manifest, and `distribution/` (source offer, attribution, relinking notes, relink-materials manifest) |
| `records/framework/` | `FRAMEWORK-RECORD.json` |
| `records/configure/`, `records/meson/`, `records/toolchain.txt` | FFmpeg's configure line and `config.mak`, the meson options and cross files of dav1d and libbluray, and the tool versions |
| `release-assets.sha256` | SHA-256 of every file attached to the release |

## Rebuilding the libraries

You need a Mac with Xcode (the artifact used Xcode 27.1 and the MacOSX 27.0
SDK), meson, ninja and pkg-config.

`build/nsurator-macos-native/script/build_nsurator_player_core_ffmpeg_artifact.sh`
is the script that built the artifact. It wants a git checkout of our player
core at the pinned revision, and it runs a step that records the player's
runtime capabilities with our player code (it writes a description into the
manifest and does not change the libraries). Neither is needed to rebuild the
libraries: the commands below run the same build steps with the copies under
`build/`.

FFmpeg keeps its configure line, which contains the work root, in the binary,
and two of its source paths too. To get the same bytes, build in the same work
root, `/tmp/nsurator-npc-artifact-build-202611121`; any other absolute path
without spaces works and gives a different checksum. Unpack the patched sources
there and the release folder beside them, dropping each archive's top-level
folder:

```sh
work=/tmp/nsurator-npc-artifact-build-202611121
mkdir -p "$work/release" && cd "$work"
tar -xJf /path/to/macos-ffmpeg-artifact-2026.11.12.1-patched-sources.tar.xz --strip-components=1
tar -C release --strip-components=1 -xzf /path/to/macos-ffmpeg-artifact-2026.11.12.1-build-scripts-and-records.tar.gz
```

This gives `sources/ffmpeg-8.1.2`, `sources/libbluray-1.4.1` (with libudfread
already in `contrib/libudfread`), `sources/libudfread-1.2.0` and
`sources/dav1d-1.5.3`, with our patches applied. (Or unpack the four upstream
archives into `$work/sources` yourself and replace the empty
`libbluray-1.4.1/contrib/libudfread` with a copy of `libudfread-1.2.0`; the
scripts then apply the patches.) Run the core build script three times, with
the settings the artifact build used:

```sh
core="$work/release/build/nsurator-player-core-e4e032f/scripts/build-ffmpeg-apple.sh"
export NSURATOR_PLAYER_CORE_APPLE_BUILD_SLICES=macosx-arm64
export NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE=base
export NSURATOR_PLAYER_CORE_FFMPEG_SWIFTPM_LINK_MODE=framework
export NSURATOR_PLAYER_CORE_EXTRA_FFMPEG_CONFIGURE_FLAGS="--enable-libdav1d --disable-network"
export NSURATOR_PLAYER_CORE_EXTRA_RUNTIME_LIBRARIES=libdav1d
export NSURATOR_PLAYER_CORE_DEP_PREFIX="$work/dependencies"
export NSURATOR_PLAYER_CORE_DAV1D_BUILD_DIR="$work/dav1d-build"
export NSURATOR_PLAYER_CORE_LIBBLURAY_BUILD_DIR="$work/libbluray-build"
export NSURATOR_PLAYER_CORE_FFMPEG_BUILD_DIR="$work/ffmpeg-build"
export NSURATOR_PLAYER_CORE_FFMPEG_INSTALL_DIR="$work/ffmpeg-install"
DAV1D_SOURCE_DIR="$work/sources/dav1d-1.5.3" "$core" --build-dav1d
LIBBLURAY_SOURCE_DIR="$work/sources/libbluray-1.4.1" "$core" --build-libbluray
FFMPEG_SOURCE_DIR="$work/sources/ffmpeg-8.1.2" "$core"
```

The static libraries end up in `$work/ffmpeg-install/macosx-arm64/lib` and
`$work/dependencies/macosx-arm64/lib`. The scripts skip patches that are
already applied. Keep `NSURATOR_PLAYER_CORE_FFMPEG_LINK_PROFILE=base` (the
default of these scripts): the `full` profile adds DVD libraries that FFmpeg
treats as GPL, and it was not used for the app.

## Building the framework

```sh
"$work/release/build/nsurator-player-core-e4e032f/scripts/package-apple-ffmpeg-runtime-framework.sh" --build \
  --ffmpeg-prefix "$work/ffmpeg-install/macosx-arm64" \
  --dependency-prefix "$work/dependencies/macosx-arm64" \
  --output-dir "$work/frameworks/macosx-arm64"
```

It force-loads every static library of the two prefixes, unchanged, into
`NsuratorPlayerCoreFFmpegRuntime.framework`, checks the layout, install name,
architecture, minimum macOS, dependencies and the exports the app uses, and
writes `FRAMEWORK-RECORD.json` beside the framework. It needs Xcode and
pkg-config (it reads the libraries' `.pc` files for their system dependencies).
`--verify <framework>` repeats the checks on any framework. The artifact build
ran the same packager through `build-ffmpeg-apple.sh --package-artifact-root`,
which first copies the two prefixes into the artifact as `install/` and
`dependencies/`.

## Replacing the libraries in the app

The app links the libraries dynamically, so you can replace them without the
app's object files:

1. Build the libraries (modified or not) and the framework as above. Keep the
   framework name and the install name, and keep the functions the app
   imports; leaving the configure flags as they are keeps all 7,349 exports.
   The app looks up seven functions of our FFmpeg patches as weak imports:
   the six `avpriv_nsurator_hls_*` functions (0011, 0012) and
   `avpriv_nsurator_vobsub_host_io_version` (0015). The libraries of this
   release define them. A framework without them still loads, and the features
   that use them (the HLS subtitle timeline, a paired VobSub `.sub` read
   through the app's own I/O) switch off.
2. Replace `Nsuve.app/Contents/Frameworks/NsuratorPlayerCoreFFmpegRuntime.framework`
   with your framework.
3. Sign the app again, inner code first: the framework, then
   `Contents/XPCServices/NsuveDecoderProbeHelper.xpc`, then the app. Either
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

- The artifact was built once. We have not built it a second time to compare
  the bytes.
- The work root is compiled into the binary (see Rebuilding), so a build in
  another directory gives a working framework with a different checksum, and
  so does another toolchain.

## 中文说明

本目录和同名 Release 是 Nsuve（原 Nsurator）for Mac 播放核心中 FFmpeg 8.1.2、
libbluray 1.4.1、libudfread 1.2.0、dav1d 1.5.3 的对应源码，适用于固定到 artifact
2026.11.12.1 的 Mac 构建，从带它对外发布的第一个构建起（应用提交 `9311b660` 固定了它，
当时的播放核心是 `e4e032fe`；版本号和 build 号在发布时补上）。之后应用的播放核心换到
`49783275`、再到 `fdba50b5`，artifact 不变：这两个提交没有改任何补丁或构建脚本，所以这些
构建加载的是同一份库。它取代 artifact 2026.10.09.1；固定到 2026.10.09.1 或
2026.09.24.1 的构建仍以各自的 Release 为准。

- 这些库放在应用内的一个框架中：
  `Nsuve.app/Contents/Frameworks/NsuratorPlayerCoreFFmpegRuntime.framework`，应用主程序
  `Nsuve` 与解码辅助进程 `NsuveDecoderProbeHelper` 通过 `@rpath` 加载它，两个可执行
  文件里都不含这些库的副本。
- 与 2026.10.09.1（原样沿用 2026.09.24.1 的静态库）不同，2026.11.12.1 于 2026-11-12
  从源码重新构建：四个上游源码包，加上播放核心 `e4e032fe` 的补丁（FFmpeg 15 个，其中 11 个
  会被编译，因为构建用了 `--disable-network`；libbluray 4 个，都会被编译）。修改说明和日期见
  `ffmpeg/CHANGES.md`、`libbluray/CHANGES.md`。
- 框架：install name `@rpath/NsuratorPlayerCoreFFmpegRuntime.framework/Versions/A/NsuratorPlayerCoreFFmpegRuntime`，
  签名前 SHA-256 `01331bb2…2f28`（23,586,080 字节），LC_UUID
  `F1E2242D-967C-3D9C-B2D4-76E74F0F2D8C`（签名不改变 UUID）。
- 重新构建：FFmpeg 会把配置参数（含工作目录）写进二进制，要得到相同字节须使用同一工作目录
  `/tmp/nsurator-npc-artifact-build-202611121`。把补丁后的源码包用 `--strip-components=1`
  解到该目录，把构建脚本包解到其中的 `release/`，按上面的命令运行
  `build/nsurator-player-core-e4e032f/scripts/build-ffmpeg-apple.sh` 三次（必须保持 `base`
  链接配置），再用 `package-apple-ffmpeg-runtime-framework.sh --build` 生成框架。
- 应用以弱引用方式查找我们补丁新增的七个函数（`avpriv_nsurator_*`）；本 Release 的库包含
  它们；你的框架没有它们也能加载，只是用到它们的功能会关闭。
- 替换：用你构建的框架（保持框架名与 install name）替换应用内的同名框架，然后按
  “框架 → 解码辅助进程 → 应用”的顺序重新签名：三者用同一个身份签名，或者用
  ad hoc 签名并给应用和辅助进程加上 `com.apple.security.cs.disable-library-validation`
  权限；不要带需要描述文件的权限。macOS 可能会在“隐私与安全性 › App 管理”中请你
  允许这次修改。替换不需要应用的目标文件。
- 重新签名的副本不再带有 Mac App Store 签名，内购、与开发者团队绑定的数据容器和
  App Group 可能无法使用。
- 无法锁定的部分：本 artifact 只构建了一次，尚未再次构建比对字节；换工作目录或换工具链
  会得到可用但校验和不同的框架。
