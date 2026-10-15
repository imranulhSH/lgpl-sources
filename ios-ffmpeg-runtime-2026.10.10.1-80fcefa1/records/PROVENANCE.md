# NsuratorPlayerCoreFFmpegRuntime 2026.10.10.1 (iPhone and iPad)

FFmpeg, libbluray (with libudfread) and dav1d, linked into one dynamic framework per slice, so the
LGPL libraries stay outside the app executable and replaceable. Built by
`scripts/build-ios-player-core-runtime.sh` from `Config/nsurator-player-core-ios-runtime.json` with the shared
player core's scripts at `307ff7139d1066a5efe2161ceddf4a81eae0ce08` (clean), Xcode 27.0 (27A266a), Apple clang version 21.0.0 (clang-2100.3.34.2), meson 1.11.2; minimum iOS 17.0;
work root `/tmp/nsurator-ios-npc-runtime-202610101` (FFmpeg keeps its configure line, with that path, in the binary).

## Sources

| Component | Upstream archive | SHA-256 |
|---|---|---|
| ffmpeg 8.1.2 | https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz | `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c` |
| libbluray 1.4.1 | https://code.videolan.org/videolan/libbluray/-/archive/1.4.1/libbluray-1.4.1.tar.gz | `e22381a313a231d94ddf9180564b36d803f33bdfc7c0b53c03868bc43e5d163d` |
| libudfread 1.2.0 | https://code.videolan.org/videolan/libudfread/-/archive/1.2.0/libudfread-1.2.0.tar.gz | `adcce1190925f9d35a477757c5e3f0e221315d14d3d45b4ae62540ea0925f877` |
| dav1d 1.5.3 | https://code.videolan.org/videolan/dav1d/-/archive/1.5.3/dav1d-1.5.3.tar.gz | `cbe212b02faf8c6eed5b6d55ef8a6e363aaab83f15112e960701a9c3df813686` |

The same archives and the same `base` (LGPL) profile as the Mac's artifact 2026.10.09.1. The patches are the
core's at that revision (`scripts/patches/`): 13 FFmpeg patches (HLS WebVTT timestamp map, HLS child network
options, HLS playing subtitle selection, HLS presentation-origin seek, HLS timeline epochs, HTTP stale-auth retry,
MOV channel-layout status, Matroska interrupt exit, Matroska invalid level, Secure Transport trust errors — not
compiled here, libssh host keys — not compiled here, network DNS errors, VobSub host-I/O inheritance) and 4
libbluray patches (Apple mobile Java home, no decryption-library loading, HDMV menu button snapshot, next coarse
angle change point); the Mac's 2026.09.24.1 libraries carry the 7 of them that existed at core 8c27b0c. GPL,
version3 and nonfree are off (`!CONFIG_GPL`, `!CONFIG_VERSION3`, `!CONFIG_NONFREE` in both config records).

## Configure (iphoneos-arm64; the simulator line differs only in SDK and target)

```
--prefix=$WORK/ffmpeg-install/iphoneos-arm64 --enable-cross-compile --target-os=darwin --arch=arm64 --cc=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang --sysroot=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk --enable-static --disable-shared --enable-pic --disable-programs --disable-doc --disable-debug --disable-avdevice --disable-devices --enable-avcodec --enable-avformat --enable-avutil --enable-swresample --enable-swscale --enable-libbluray --enable-videotoolbox --pkg-config=/opt/homebrew/bin/pkg-config --extra-cflags='-target arm64-apple-ios17.0 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk -fembed-bitcode -fPIC -I$WORK/dependencies/iphoneos-arm64/include' --extra-ldflags='-target arm64-apple-ios17.0 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk -L$WORK/dependencies/iphoneos-arm64/lib' --enable-libdav1d --disable-securetransport --disable-protocols --enable-protocol='async,bluray,cache,concat,concatf,crypto,data,fd,file,hls,http,pipe,subfile,tcp'
```

Against the Mac: the Mac adds `--disable-network`; this runtime keeps plain `http` and `tcp` (no TLS, no
SecureTransport) for the app's loopback HLS proxy: `--enable-libdav1d --disable-securetransport --disable-protocols --enable-protocol=async,bluray,cache,concat,concatf,crypto,data,fd,file,hls,http,pipe,subfile,tcp`.

## Binaries

| Slice | SHA-256 (before signing) | LC_UUID | Bytes |
|---|---|---|---|
| iphoneos-arm64 | `80fcefa1b69d423df5e7dde95156e9189118f1cef2b00c0b99bb9c94a3a5d2ea` | `A4A43AE8-105A-31F4-88CA-C5EAA327E028` | 22,989,296 |
| iphonesimulator-arm64 | `bbd2798118f181e94802f9d7f12e085a597342d84f616de26156bbbf832c7dc0` | `E92981BB-B2F9-3041-BB08-9476BCD156D5` | 23,763,728 |

Install name `@rpath/NsuratorPlayerCoreFFmpegRuntime.framework/NsuratorPlayerCoreFFmpegRuntime`; system dependencies
only (AudioToolbox, CoreFoundation, CoreMedia, CoreVideo, VideoToolbox, libSystem, libbz2, libiconv, libz); each slice
carries `PrivacyInfo.xcprivacy` (file timestamps, 3B52.1 and C617.1; no tracking, no collected data). The vendored
runtime it replaces (FFmpeg 8.1, dav1d 1.5.4, no avfilter, with TLS) was 19,288,104 bytes (device) and
19,835,584 bytes (simulator); this one adds libavfilter (the core's deinterlacing) and drops TLS.

`records/` holds the configure lines and each slice's `FRAMEWORK-RECORD.json` (the link command with relative paths,
the checksum of every static input, the export list checksum, the toolchain).

## Corresponding source

Release `ios-ffmpeg-runtime-2026.10.10.1-80fcefa1` on
github.com/imranulhSH/lgpl-sources (to be published before this runtime ships), linked from 开源许可.
