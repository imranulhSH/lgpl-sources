# iPhone and iPad app: FFmpeg runtime 2026.10.10.1

Release tag: `ios-ffmpeg-runtime-2026.10.10.1-80fcefa1`

This folder and its release are the corresponding source for
`NsuratorPlayerCoreFFmpegRuntime.framework`, the media library framework inside
Nsurator for iPhone and iPad 1.0.3 (build 103) and 1.0.4 (build 104), the
builds that play through the shared player core (first app commit `8d06cdd`;
1.0.4 is app commit `eeaf8d8` on `main`). It replaces the 1.0.1 runtime
`VisionPlayerCoreFFmpegRuntime` (release `ios-1.0.1-ffmpeg-runtime-94a31390`).
Both builds embed the same binary, byte for byte before signing.

## The shipped binary

| | |
|---|---|
| Path in the app | `NsuratorPhone.app/Frameworks/NsuratorPlayerCoreFFmpegRuntime.framework/NsuratorPlayerCoreFFmpegRuntime` |
| Linking | Dynamic framework (shallow iOS bundle, no headers). Install name `@rpath/NsuratorPlayerCoreFFmpegRuntime.framework/NsuratorPlayerCoreFFmpegRuntime`, compatibility version 1.0.0. The app finds it through `@executable_path/Frameworks`. |
| Device slice (ios-arm64) SHA-256, before signing | `80fcefa1b69d423df5e7dde95156e9189118f1cef2b00c0b99bb9c94a3a5d2ea` (LC_UUID `A4A43AE8-105A-31F4-88CA-C5EAA327E028`, 22,989,296 bytes) |
| Simulator slice (ios-arm64-simulator) SHA-256 | `bbd2798118f181e94802f9d7f12e085a597342d84f616de26156bbbf832c7dc0` (LC_UUID `E92981BB-B2F9-3041-BB08-9476BCD156D5`) |
| Pinned by | `build/nsurator-iphone-native/scripts/ios-ffmpeg-runtime-lock.json` |
| Contains | FFmpeg (libavformat, libavcodec, libavfilter, libavutil, libswresample, libswscale), libbluray with libudfread, and dav1d. No app code. |

The App Store copy differs from the SHA-256 above only by its code signature;
compare the UUID (`dwarfdump --uuid`) instead.

## Components

| Component | Licence | Upstream archive (attached unchanged) | SHA-256 | Our changes |
|---|---|---|---|---|
| FFmpeg 8.1.2 | LGPL-2.1-or-later | https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz | `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c` | 13 patches, see `ffmpeg/CHANGES.md` |
| libbluray 1.4.1 | LGPL-2.1-or-later | https://code.videolan.org/videolan/libbluray/-/archive/1.4.1/libbluray-1.4.1.tar.gz | `e22381a313a231d94ddf9180564b36d803f33bdfc7c0b53c03868bc43e5d163d` | 4 patches, see `libbluray/CHANGES.md` |
| libudfread 1.2.0 | LGPL-2.1-or-later | https://code.videolan.org/videolan/libudfread/-/archive/1.2.0/libudfread-1.2.0.tar.gz | `adcce1190925f9d35a477757c5e3f0e221315d14d3d45b4ae62540ea0925f877` | none |
| dav1d 1.5.3 | BSD-2-Clause | https://code.videolan.org/videolan/dav1d/-/archive/1.5.3/dav1d-1.5.3.tar.gz | `cbe212b02faf8c6eed5b6d55ef8a6e363aaab83f15112e960701a9c3df813686` | none |

These are the same upstream archives as the Mac's FFmpeg artifact 2026.10.09.1
(release `macos-ffmpeg-artifact-2026.10.09.1`).

## Build configuration

- Recipe: `build/nsurator-iphone-native/Config/nsurator-player-core-ios-runtime.json`,
  run by `build/nsurator-iphone-native/scripts/build-ios-player-core-runtime.sh`
  with the player core's scripts at commit `307ff7139d1066a5efe2161ceddf4a81eae0ce08`
  (`build/nsurator-player-core-307ff71/scripts/`), work root
  `/tmp/nsurator-ios-npc-runtime-202610101`.
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
- Toolchain: Xcode 27.0 (27A266a), iPhoneOS/iPhoneSimulator 27.0 SDKs, Apple
  clang 21.0.0 (clang-2100.3.34.2), meson 1.11.2; minimum iOS 17.0.

## Folder contents

| Path | What it is |
|---|---|
| `ffmpeg/patches/`, `libbluray/patches/` | The patches, numbered in the order they are applied |
| `ffmpeg/CHANGES.md`, `libbluray/CHANGES.md` | Dated change notices |
| `*/COPYING*`, `ffmpeg/LICENSE.md` | Licence texts from the upstream sources |
| `libudfread/README.md`, `dav1d/README.md` | Source notes (no changes) |
| `build/nsurator-player-core-307ff71/scripts/` | The player core's build and packaging scripts and its patch directory at commit `307ff71` |
| `build/nsurator-iphone-native/` | The app repository's runtime recipe, build script, reviewed lock and audit script |
| `records/` | Configure and meson records, framework records, toolchain, the app's provenance note (`PROVENANCE.md`), and the symbols the app imports from the framework: 120 required (`app-imports-from-NsuratorPlayerCoreFFmpegRuntime.txt`) and 7 weak (`app-optional-imports.txt`), from a Release build of commit `8d06cdd` |
| `assets/` | The files to attach to the release, and `release-assets.sha256` |

## Rebuilding

You need a Mac with Xcode 27.0 (iPhoneOS 27.0 SDK), meson, ninja, nasm,
pkg-config and python3.

```sh
mkdir work && cd work
tar -xzf ios-ffmpeg-runtime-2026.10.10.1-80fcefa1-build-scripts-and-records.tar.gz --strip-components=1
mkdir cache && cp ffmpeg-8.1.2.tar.xz libbluray-1.4.1.tar.gz libudfread-1.2.0.tar.gz dav1d-1.5.3.tar.gz cache/
build/nsurator-iphone-native/scripts/build-ios-player-core-runtime.sh \
  --core-root "$PWD/build/nsurator-player-core-307ff71" \
  --work-root /tmp/nsurator-ios-npc-runtime-202610101 --source-cache "$PWD/cache"
```

(`build-ios-player-core-runtime.sh` expects the recipe at `../Config/` from its
own directory, which is how `build/nsurator-iphone-native/` is laid out. It
checks every archive's SHA-256, unpacks them, applies the patches and builds
both slices.) The FFmpeg configure line, which contains the work root, is
compiled into the binary, so use the same work root to get the same bytes.
`patched-sources.tar.xz` holds the four trees after patching, for reading or for
building by hand with the commands in the records.

The build is reproducible: on 2026-10-10 the runtime was built twice in
`/tmp/nsurator-ios-npc-runtime-202610101` from the same inputs, and both slices
were byte-identical (device `80fcefa1…`, simulator `bbd27981…`). The player core
commit that ran was `307ff713` the first time and `09825fa6` (documentation
only on top of it) the second; the scripts are the same in both.

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
