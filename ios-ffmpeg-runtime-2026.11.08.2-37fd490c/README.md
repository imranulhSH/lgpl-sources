# iPhone and iPad app: FFmpeg runtime 2026.11.08.2

Release tag: `ios-ffmpeg-runtime-2026.11.08.2-37fd490c`

This folder and its release are the corresponding source for
`NsuratorPlayerCoreFFmpegRuntime.framework`, the media library framework inside
Nsuve (formerly Nsurator) for iPhone and iPad 1.2.1 (build 127), the first build
distributed with it (app commit `30765e37`). It replaces runtime 2026.10.10.1 (release
`ios-ffmpeg-runtime-2026.10.10.1-80fcefa1`): the same sources and recipe, one
more FFmpeg patch (Matroska `CueRelativePosition` seeks, `ffmpeg/CHANGES.md`
0014), built with Xcode 27.1. Runtime 2026.11.08.1 (`aeed96c0`) was never
distributed, nor was a first build of 2026.11.08.2 in another work root (device
slice `5c3b3bc9`); the work root is part of the binary, see Rebuilding.

## The shipped binary

| | |
|---|---|
| Path in the app | `NsuratorPhone.app/Frameworks/NsuratorPlayerCoreFFmpegRuntime.framework/NsuratorPlayerCoreFFmpegRuntime` |
| Linking | Dynamic framework (shallow iOS bundle, no headers). Install name `@rpath/NsuratorPlayerCoreFFmpegRuntime.framework/NsuratorPlayerCoreFFmpegRuntime`, compatibility version 1.0.0. The app finds it through `@executable_path/Frameworks`. |
| Device slice (ios-arm64) SHA-256, before signing | `37fd490c99226e390e49ea14a58d0ac8b42abbd9435c084e703233261882c9c3` (LC_UUID `970F92B7-B193-31DD-A56C-0BDAE9703C68`, 22,989,456 bytes) |
| Simulator slice (ios-arm64-simulator) SHA-256 | `765339a09cf3af1eca47b5be81ee7bb53ea9af2bc7b4e4c7d8154ff6ff47681c` (LC_UUID `CD3C360E-9925-371F-BD9E-8BC315761FAD`) |
| Pinned by | `build/nsurator-iphone-native/scripts/ios-ffmpeg-runtime-lock.json` |
| Contains | FFmpeg (libavformat, libavcodec, libavfilter, libavutil, libswresample, libswscale), libbluray with libudfread, and dav1d. No app code. |

The App Store copy differs from the SHA-256 above only by its code signature;
compare the UUID (`dwarfdump --uuid`) instead.

## Components

| Component | Licence | Upstream archive (attached unchanged) | SHA-256 | Our changes |
|---|---|---|---|---|
| FFmpeg 8.1.2 | LGPL-2.1-or-later | https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz | `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c` | 14 patches, see `ffmpeg/CHANGES.md` |
| libbluray 1.4.1 | LGPL-2.1-or-later | https://code.videolan.org/videolan/libbluray/-/archive/1.4.1/libbluray-1.4.1.tar.gz | `e22381a313a231d94ddf9180564b36d803f33bdfc7c0b53c03868bc43e5d163d` | 4 patches, see `libbluray/CHANGES.md` |
| libudfread 1.2.0 | LGPL-2.1-or-later | https://code.videolan.org/videolan/libudfread/-/archive/1.2.0/libudfread-1.2.0.tar.gz | `adcce1190925f9d35a477757c5e3f0e221315d14d3d45b4ae62540ea0925f877` | none |
| dav1d 1.5.3 | BSD-2-Clause | https://code.videolan.org/videolan/dav1d/-/archive/1.5.3/dav1d-1.5.3.tar.gz | `cbe212b02faf8c6eed5b6d55ef8a6e363aaab83f15112e960701a9c3df813686` | none |

These are the same upstream archives as the Mac's FFmpeg artifact 2026.10.09.1
(release `macos-ffmpeg-artifact-2026.10.09.1`).

## Build configuration

- Recipe: `build/nsurator-iphone-native/Config/nsurator-player-core-ios-runtime.json`,
  run by `build/nsurator-iphone-native/scripts/build-ios-player-core-runtime.sh`
  with the player core's scripts at commit `e50a3b0b342c6cc6f12199800621678ed76baf25`
  (`build/nsurator-player-core-e50a3b0/scripts/`), work root
  `/tmp/nsurator-ios-npc-runtime-202611082`.
- FFmpeg configure line: `records/configure/ffmpeg-iphoneos-arm64-configure.txt`
  (full record: `ffmpeg-iphoneos-arm64-config.mak`); the simulator slice differs
  only in SDK and target. Link profile `base`; extra flags
  `--enable-libdav1d --disable-securetransport --disable-protocols --enable-protocol=async,bluray,cache,concat,concatf,crypto,data,fd,file,hls,http,pipe,subfile,tcp`.
  GPL, nonfree and version3 are all off (`!CONFIG_GPL`, `!CONFIG_NONFREE`,
  `!CONFIG_VERSION3` in both config records). No TLS is compiled.
- libbluray and dav1d: meson, static, release (`records/meson/*-build-options.txt`
  and the cross files).
- Framework: every static archive force-loaded, unchanged, into one dynamic
  image per slice by `package-apple-ffmpeg-runtime-framework.sh --sdk iphoneos`
  / `--sdk iphonesimulator`; the exact link command (paths relative to the work
  root), the SHA-256 of each input archive and of the export list are in
  `records/framework/*-FRAMEWORK-RECORD.json`. The two slices are joined with
  `xcodebuild -create-xcframework`.
- Toolchain: Xcode 27.1 (27A9275), iPhoneOS/iPhoneSimulator 27.1 SDKs, Apple
  clang 21.0.0 (clang-2100.3.34.2), meson 1.11.2; minimum iOS 17.0.

## Folder contents

| Path | What it is |
|---|---|
| `ffmpeg/patches/`, `libbluray/patches/` | The patches, numbered in the order they are applied |
| `ffmpeg/CHANGES.md`, `libbluray/CHANGES.md` | Dated change notices |
| `*/COPYING*`, `ffmpeg/LICENSE.md` | Licence texts from the upstream sources |
| `libudfread/README.md`, `dav1d/README.md` | Source notes (no changes) |
| `build/nsurator-player-core-e50a3b0/scripts/` | The player core's build and packaging scripts and its patch directory at commit `e50a3b0` |
| `build/nsurator-iphone-native/` | The app repository's runtime recipe, build script, reviewed lock and audit script |
| `records/` | Configure and meson records, framework records, toolchain, the app's provenance note (`PROVENANCE.md`), and the symbols the app imports from the framework: 129 required (`app-imports-from-NsuratorPlayerCoreFFmpegRuntime.txt`) and 7 weak (`app-optional-imports.txt`), from a Release build of commit `30765e37` |
| `assets/` | The files to attach to the release, and `release-assets.sha256` |

## Rebuilding

You need a Mac with Xcode 27.1 (iPhoneOS 27.1 SDK), meson, ninja, nasm,
pkg-config and python3.

```sh
mkdir work && cd work
tar -xzf ios-ffmpeg-runtime-2026.11.08.2-37fd490c-build-scripts-and-records.tar.gz --strip-components=1
mkdir cache && cp ffmpeg-8.1.2.tar.xz libbluray-1.4.1.tar.gz libudfread-1.2.0.tar.gz dav1d-1.5.3.tar.gz cache/
build/nsurator-iphone-native/scripts/build-ios-player-core-runtime.sh \
  --core-root "$PWD/build/nsurator-player-core-e50a3b0" \
  --work-root /tmp/nsurator-ios-npc-runtime-202611082 --source-cache "$PWD/cache"
```

(`build-ios-player-core-runtime.sh` expects the recipe at `../Config/` from its
own directory, which is how `build/nsurator-iphone-native/` is laid out. It
checks every archive's SHA-256, unpacks them, applies the patches and builds
both slices.) The FFmpeg configure line, which contains the work root, is
compiled into the binary, so use the same work root to get the same bytes.
`patched-sources.tar.xz` holds the four trees after patching, for reading or for
building by hand with the commands in the records.

The build is reproducible: on 2026-11-09 the runtime was built three times in
`/tmp/nsurator-ios-npc-runtime-202611082` from the same inputs, and both slices came out byte-identical
each time (device `37fd490c…`, simulator `765339a0…`). The first two builds ran
from these files laid out as above (`--core-root` the
`build/nsurator-player-core-e50a3b0` folder), the third from a checkout of the
player core at commit `e50a3b0b` (`records/toolchain.txt`).

## Replacing the framework in the app

A replacement must:

- be a dynamic framework named `NsuratorPlayerCoreFFmpegRuntime.framework`
  with install name `@rpath/NsuratorPlayerCoreFFmpegRuntime.framework/NsuratorPlayerCoreFFmpegRuntime`;
- be built for arm64 iOS with a deployment target of iOS 17.0 or lower;
- export every symbol in `records/app-imports-from-NsuratorPlayerCoreFFmpegRuntime.txt`
  with the same C ABI (libavformat 62, libavcodec 62, libavfilter 11, libavutil
  60, libswresample 6, libswscale 9, libbluray 1.4 with overlay interface 3 and
  `bd_select_hdmv_menu_button`). The `avpriv_nsurator_*` functions in
  `records/app-optional-imports.txt` are weak imports: a framework without them
  loads, and the features that use them (HLS subtitle timeline, paired VobSub
  through host I/O) switch off.

Put it in place of `Frameworks/NsuratorPlayerCoreFFmpegRuntime.framework`, then
sign the framework and the app again with your own certificate and a
provisioning profile that includes your device, and install with Xcode or
`xcrun devicectl`.

What iOS allows: iOS runs only code signed by Apple or by a developer
certificate whose provisioning profile includes the device. Copies of the app
installed from the App Store are encrypted and signed by Apple, so a framework
cannot be replaced inside an App Store installation on an unmodified device.
The replacement steps above work only for a copy of the app that you are able
to sign and install yourself.
