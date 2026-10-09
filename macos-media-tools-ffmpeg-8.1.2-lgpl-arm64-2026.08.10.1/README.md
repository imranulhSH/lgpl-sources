# Mac app: ffmpeg and ffprobe tools 2026.08.10.1

Release tag: `macos-media-tools-ffmpeg-8.1.2-lgpl-arm64-2026.08.10.1`

This folder and its release are the corresponding source for the `ffmpeg` and
`ffprobe` command-line programs bundled with Nsurator for Mac.

## Which app builds use it

Nsurator for Mac builds made from the app's source on or after 2026-08-11,
when this tools artifact was pinned. That covers versions 6.9.9 through 6.9.17
and 5.9.17 (the version line was renumbered from 6.9.x to 5.9.x on
2026-09-21). Builds made before 2026-08-11 bundled different tools and are not
covered by this release.

This release covers only the `ffmpeg` and `ffprobe` programs. The player
libraries linked into the app itself are a separate library set: for builds
made on or after 2026-09-24 they are covered by the release
`macos-ffmpeg-artifact-2026.09.24.1`. Builds made from 2026-08-11 to
2026-09-23 used earlier player library builds, which no release in this
repository covers. The versions above say which builds contain these tools;
they are not a list of builds that are fully covered here.

The tools are separate executables that the app starts as child processes:

| File in the app | SHA-256 before App Store signing |
|---|---|
| `Nsurator.app/Contents/Resources/PlaybackTools/ffmpeg` | `7d8bba6092f12288dd84d634f42d47104192ad3173bbc70e5fea07cac4de4e59` |
| `Nsurator.app/Contents/Resources/PlaybackTools/ffprobe` | `ce412ad1c9a26621577eb168222193dafeeff370386544958abf7c00bd0a30d2` |

The app's packaging signs both files again, which changes their hashes in the
shipped app. Each tool contains only the third-party code below; no app code
is linked into them.

## Components

All linked statically into each tool. None of them is modified.

| Component | Licence | Upstream archive | SHA-256 |
|---|---|---|---|
| FFmpeg 8.1.2 (including libavdevice and libavfilter) | LGPL-2.1-or-later | https://ffmpeg.org/releases/ffmpeg-8.1.2.tar.xz | `464beb5e7bf0c311e68b45ae2f04e9cc2af88851abb4082231742a74d97b524c` |
| FriBidi 1.0.16 | LGPL-2.1-or-later | https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz | `1b1cde5b235d40479e91be2f0e88a309e3214c8ab470ec8a2744d82a5a9ea05c` |
| libass 0.17.5 | ISC | https://github.com/libass/libass/releases/download/0.17.5/libass-0.17.5.tar.xz | `2dca25c0e0c837ddf00b52011b3f82cac1e4ddd3ad018227806b0c2288864acc` |
| FreeType 2.14.3 | FreeType License (FTL) | https://downloads.sourceforge.net/project/freetype/freetype2/2.14.3/freetype-2.14.3.tar.xz | `36bc4f1cc413335368ee656c42afca65c5a3987e8768cc28cf11ba775e785a5f` |
| HarfBuzz 14.3.0 | MIT | https://github.com/harfbuzz/harfbuzz/releases/download/14.3.0/harfbuzz-14.3.0.tar.xz | `16070d77cfc4ba1f1e7327e83bf9b3f55898081cabdb94e56a33e04fc8874eae` |
| libunibreak 7.0 | Zlib | https://github.com/adah1972/libunibreak/releases/download/libunibreak_7_0/libunibreak-7.0.tar.gz | `8c9a6e121736cd0d5c890ae3ae96f3f4010a19aa040f1dbded833a62a87717d3` |
| libpng 1.6.58 | libpng-2.0 | https://downloads.sourceforge.net/project/libpng/libpng16/1.6.58/libpng-1.6.58.tar.xz | `28eb403f51f0f7405249132cecfe82ea5c0ef97f1b32c5a65828814ae0d34775` |

The release attaches the exact archives the build used. Because nothing is
patched, the source the build compiled is these archives unpacked; there is no
separate patched-source archive for this release.

## Build configuration

- FFmpeg configure flags (from `records/build-configuration.txt`):
  `--arch=arm64 --extra-libs=-lc++ --pkg-config-flags=--static --disable-debug --disable-doc --disable-ffplay --disable-gpl --disable-nonfree --disable-shared --enable-audiotoolbox --enable-libass --enable-pic --enable-securetransport --enable-static --enable-videotoolbox`,
  plus `--prefix`, `--cc`, `--cxx` and `-O2 -arch arm64 -mmacosx-version-min=14.0`
  compiler and linker flags.
- Compiler: Apple clang 21.0.0 (clang-2100.1.1.101), MacOSX 26.5 SDK, minimum
  macOS 14.0.
- The dependencies' meson and configure options are in
  `build/script/build_media_tools_artifact.sh`.

## Folder contents

| Path | What it is |
|---|---|
| `build/script/build_media_tools_artifact.sh`, `build/script/media_tools_artifact_common.sh` | The build scripts as they ran (copied into the artifact by the build) |
| `build/Config/media-tools-sources.json` | Source pins (SHA-256 `9eebeee67657ea9d3775891a0a428f3a82ccad4f06afc357f6e110ae4457416d`, as recorded in the lock) |
| `build/Config/media-tools-artifact.lock.json` | The app's lock for this artifact: tool hashes and required and forbidden configure flags |
| `build/Sources/NsuratorNative/Resources/ThirdPartyPlayback/MEDIA-TOOLS-NOTICE.md` | The notice the build copies into the artifact and the app shows with the tools (placed where the script looks for it) |
| `records/` | Build configuration, `ffmpeg -buildconf` and `ffmpeg -version` output |
| `<component>/` | Licence texts from each upstream source |
| `release-assets.sha256` | SHA-256 of every file attached to the release |

## Rebuilding

You need a Mac with Xcode, meson, ninja, pkg-config and make. The script
expects to sit in a checkout with `script/` and `Config/` next to each other,
which is the layout of `build/`:

```sh
build/script/build_media_tools_artifact.sh --source-cache /path/to/the/release/archives --work-root /absolute/new/directory
```

It checks each archive's SHA-256, builds libpng, FreeType, FriBidi, HarfBuzz,
libunibreak, libass and FFmpeg as static libraries, and writes `ffmpeg` and
`ffprobe` with their licences into `build/.build/media-tools-artifacts/dist/`
(or the directory given with `--dist-root`). Avoid spaces in all of these paths.

## Replacing the tools in the app

The tools are separate programs, so a rebuilt `ffmpeg` or `ffprobe` can
replace the files in `Contents/Resources/PlaybackTools/`. They must stay arm64
executables for macOS 14.0 or later that link only system libraries, and they
need the `ass`, `overlay` and `subtitles` filters and the `aac`, `gif`,
`h264_videotoolbox`, `mjpeg` and `png` encoders that the app uses.

Changing a file inside the app breaks the app's signature, so the tool and
the app have to be signed again. A re-signed copy no longer carries the Mac
App Store signature, so features that depend on it (in-app purchases, and data
containers and app groups tied to the developer's team) may not work in that
copy.

## What we could not pin

- The packed artifact archive (`nsurator-media-tools-ffmpeg-8.1.2-lgpl-arm64-2026.08.10.1.tar.gz`,
  SHA-256 `78fc1db5d026cec733149fad4240656a18fbeb57b3604a0c0d116a810387c357`)
  was not kept, but its unpacked contents were: the tool hashes and source
  archive hashes all match the lock.
- The meson, ninja and pkg-config versions were not recorded.
- The app repository's current copy of `media_tools_artifact_common.sh` has
  two more checking functions than the copy that ran; the build steps are the
  same.

## 中文说明

本目录和同名 Release 是 Nsurator for Mac 附带的 `ffmpeg` / `ffprobe` 命令行工具的
对应源码，适用于 2026-08-11 之后构建的版本（6.9.9 至 6.9.17，以及 5.9.17）。

- 本 Release 只覆盖 `ffmpeg` / `ffprobe` 这两个程序。应用本身链接的播放核心库是
  另一套：2026-09-24 及之后的构建由 `macos-ffmpeg-artifact-2026.09.24.1` 覆盖；
  2026-08-11 至 2026-09-23 之间的构建使用更早的播放核心库构建，本仓库没有对应的
  Release。上面的版本号说明哪些构建包含这两个工具，并不表示这些构建已全部覆盖。
- 两个工具是独立程序，静态链入 FFmpeg 8.1.2、FriBidi 1.0.16（LGPL）以及 libass、
  FreeType、HarfBuzz、libunibreak、libpng（宽松许可）。全部未修改，因此没有补丁包，
  编译的源码就是附带的上游源码包。
- 重新构建：`build/script/build_media_tools_artifact.sh --source-cache <源码包目录> --work-root <新的绝对路径>`。
- 替换：直接替换应用内 `Contents/Resources/PlaybackTools/` 中的文件，然后重新签名。
  重新签名的副本不再带有 Mac App Store 签名，内购、与开发者团队绑定的数据容器和
  App Group 可能无法使用。
