# Nsurator LGPL sources

[中文说明](#中文说明)

This repository holds the corresponding source for the LGPL-licensed
libraries that ship inside the Nsurator apps: our patches to those libraries,
the build scripts and configure flags we used, the build records, and the
licence texts. The full source archives are attached to this repository's
GitHub Releases, one release per shipped library set.

The Nsurator apps themselves are not open source, and their source code is
not here. Everything in this repository is either third-party source, our
changes to it, or what is needed to rebuild it.

## Which app builds use which release

| Release tag | App builds | Libraries (LGPL in bold) | How the app links them |
|---|---|---|---|
| [`ios-1.0.1-ffmpeg-runtime-94a31390`](ios-1.0.1-ffmpeg-runtime-94a31390/) | Nsurator for iPhone and iPad 1.0.1 (build 101) | **FFmpeg 8.1** (7 patches), **libbluray 1.4.1** (3 changes), **libudfread** (1.2.0 plus 3 upstream commits), dav1d 1.5.4 | Dynamic framework `VisionPlayerCoreFFmpegRuntime.framework` |
| [`ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6`](ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6/) | Nsurator for iPhone and iPad 1.0.1 (build 101) | **libsmb2** (2 patches) and **AMSMB2 4.0.3** (1 patch) | Dynamic framework `AMSMB2.framework` |
| [`macos-ffmpeg-artifact-2026.09.24.1`](macos-ffmpeg-artifact-2026.09.24.1/) | Nsurator for Mac 5.9.17 (build 8), builds made on or after 2026-09-24 that pin this artifact | **FFmpeg 8.1.2** (7 patches), **libbluray 1.4.1** (3 patches), **libudfread 1.2.0**, dav1d 1.5.3 | Static, inside the app executable and its decoder helper |
| [`macos-ffmpeg-artifact-2026.10.09.1`](macos-ffmpeg-artifact-2026.10.09.1/) | Nsurator for Mac builds that pin artifact 2026.10.09.1 (player core `ebfc8a0`) | The same libraries as 2026.09.24.1, byte for byte | Dynamic framework `NsuratorPlayerCoreFFmpegRuntime.framework`, loaded by the app executable and its decoder helper |
| [`macos-media-tools-ffmpeg-8.1.2-lgpl-arm64-2026.08.10.1`](macos-media-tools-ffmpeg-8.1.2-lgpl-arm64-2026.08.10.1/) | Nsurator for Mac builds made on or after 2026-08-11 (6.9.9 through 6.9.17, and 5.9.17) | **FFmpeg 8.1.2**, **FriBidi 1.0.16**, libass 0.17.5, FreeType 2.14.3, HarfBuzz 14.3.0, libunibreak 7.0, libpng 1.6.58 (all unmodified) | Separate `ffmpeg` and `ffprobe` programs |

Each folder's README gives the exact source pins, the configure flags, how to
rebuild, how to replace the library in the app, and anything we could not pin.

A release covers only the libraries in its own row. The "App builds" column
says which builds contain those libraries.

Earlier Mac builds were internal builds and were never distributed, so no
release is needed for them. They include 6.9.1 through 6.9.8 (2026-07-31 to
2026-08-10), which bundled different ffmpeg and ffprobe tools, and every build
that used a player library build from before 2026-09-24, including all builds
made from 2026-08-11 to 2026-09-23 (6.9.9 through 6.9.17, and 5.9.17 builds
made before 2026-09-24). Of the Mac builds in the table, only those made on or
after 2026-09-24 were distributed.

## Getting the source

Open the release for your app build on the
[Releases page](https://github.com/imranulhSH/lgpl-sources/releases). Each
release has:

- the upstream source archives, byte for byte as the build used them;
- `<tag>-patches.tar.gz`: our patch series and change notices (not present
  when nothing was changed);
- `<tag>-patched-sources.tar.xz`: the source tree after our patches, which is
  what the build compiled (not present when nothing was changed);
- `<tag>-build-scripts-and-records.tar.gz`: the release's folder from this
  repository (everything except `release-assets.sha256`);
- `SHA256SUMS`.

Check the downloads with:

```sh
shasum -a 256 -c SHA256SUMS
```

The same hashes are in each folder's `release-assets.sha256`, and
[`SHA256SUMS`](SHA256SUMS) at the top of this repository covers every file in
the repository.

## Rebuilding

All builds need a Mac with Xcode. Each folder's `build/` directory keeps the
scripts in the layout they had in our repositories, so they run from there.
In short:

- iPhone/iPad FFmpeg runtime:
  `build/scripts/rebuild-ios-ffmpeg-runtime.sh /absolute/new/directory`
- iPhone/iPad AMSMB2: build the `AMSMB2` Swift package from the patched
  source archive with Xcode.
- Mac FFmpeg artifact: run
  `build/nsurator-player-core/scripts/build-ffmpeg-apple.sh` three times
  (dav1d, libbluray, FFmpeg) with the settings listed in the folder's README.
  For 2026.10.09.1, then package the framework with
  `build/nsurator-player-core-ebfc8a0/scripts/package-apple-ffmpeg-runtime-framework.sh --build`.
- Mac ffmpeg/ffprobe tools:
  `build/script/build_media_tools_artifact.sh --source-cache <archives> --work-root <new directory>`

The build scripts in these releases default to a `full` profile that adds
libraries FFmpeg treats as GPL (from player core `ebfc8a0` on, `base` is the
default). The apps use the `base` profile, and the instructions here set it.
Do not use `full` if you want to rebuild what the apps ship.

## Replacing a library in the app

- **iPhone and iPad.** Both libraries are dynamic frameworks. Build a
  framework with the same name, install name and exported symbols (each
  folder lists the symbols the app uses), put it in the app's `Frameworks`
  folder, then sign the app again with your own developer certificate and a
  provisioning profile that includes your device. iOS runs only code signed
  by Apple or by such a certificate, and App Store copies of the app are
  encrypted and signed by Apple. A framework therefore cannot be replaced
  inside an App Store installation on an unmodified device; the steps work
  only for a copy of the app you are able to sign and install yourself.
- **Mac, ffmpeg and ffprobe tools.** These are separate programs in
  `Contents/Resources/PlaybackTools/`. Replace them with your own build and
  sign the app again.
- **Mac, player libraries, artifact 2026.10.09.1 and later.** The libraries
  are one dynamic framework, `Contents/Frameworks/NsuratorPlayerCoreFFmpegRuntime.framework`.
  Build a framework with the same name and install name, replace it, and sign
  the framework, the decoder helper and the app again; that folder's README
  gives the commands and the signing rules.
- **Mac, player libraries, artifact 2026.09.24.1.** These are linked
  statically into the app and its decoder helper. Relinking them needs the
  app's object files, which are not in this repository. The Nsurator support
  page (https://www.nsurator.com/support.html#oss) explains how to ask for the
  materials needed to relink.

On the Mac, a re-signed copy no longer carries the Mac App Store signature, so
features that depend on it (in-app purchases, and data containers and app
groups tied to the developer's team) may not work in that copy.

## Licences

Each component folder has the licence texts from that component's own source
(for example `ffmpeg/COPYING.LGPLv2.1`). Our patches change LGPL-2.1-or-later
libraries and are distributed under the same licence as the library they
change, unless the patch itself says otherwise (one AMSMB2 patch adds a Swift
file under MIT, like AMSMB2's own Swift files; see that folder's
`CHANGES.md`). Each patched component has a `CHANGES.md` that lists the files
we changed and when. The changed source files do not carry dated notices of
their own: so that the patches stay exactly as they were built, the dated
notice for every changed file is in its component's `CHANGES.md`.

The files we wrote ourselves (the build scripts and build records copied from
our repositories, the READMEs and the change notices) are licensed under the
GNU Lesser General Public License, version 2.1 or (at your option) any later
version, the same licence as the libraries they build. The text is in
[`LICENSE`](LICENSE). Files that state their own licence keep it, and the
third-party files here (licence texts, upstream build manifests) keep the
licence of the project they come from.

## Contact

See https://www.nsurator.com/support.html#oss.

---

## 中文说明

本仓库存放 Nsurator 应用中以 LGPL 许可分发的第三方库的对应源码：我们对这些库的
补丁、实际使用的构建脚本和配置参数、构建记录，以及许可证全文。完整的源码包放在
本仓库的 GitHub Releases 中，每套随应用发布的库对应一个 Release。

Nsurator 应用本身不开源，其源代码不在这里。本仓库只包含第三方源码、我们对它的
修改，以及重新构建所需的内容。

### 应用版本与 Release 的对应关系

| Release 标签 | 应用版本 | 库（粗体为 LGPL） | 链接方式 |
|---|---|---|---|
| `ios-1.0.1-ffmpeg-runtime-94a31390` | Nsurator iPhone/iPad 1.0.1（101） | **FFmpeg 8.1**（7 个补丁）、**libbluray 1.4.1**（3 处修改）、**libudfread**（1.2.0 之后 3 个上游提交）、dav1d 1.5.4 | 动态框架 `VisionPlayerCoreFFmpegRuntime.framework` |
| `ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6` | Nsurator iPhone/iPad 1.0.1（101） | **libsmb2**（2 个补丁）、**AMSMB2 4.0.3**（1 个补丁） | 动态框架 `AMSMB2.framework` |
| `macos-ffmpeg-artifact-2026.09.24.1` | Nsurator for Mac 5.9.17（build 8），2026-09-24 及之后、固定到此 artifact 的构建 | **FFmpeg 8.1.2**（7 个补丁）、**libbluray 1.4.1**（3 个补丁）、**libudfread 1.2.0**、dav1d 1.5.3 | 静态链接进应用主程序和解码辅助进程 |
| `macos-ffmpeg-artifact-2026.10.09.1` | 固定到 artifact 2026.10.09.1（播放核心 `ebfc8a0`）的 Mac 构建 | 与 2026.09.24.1 完全相同的库 | 动态框架 `NsuratorPlayerCoreFFmpegRuntime.framework`，由应用主程序和解码辅助进程加载 |
| `macos-media-tools-ffmpeg-8.1.2-lgpl-arm64-2026.08.10.1` | 2026-08-11 及之后构建的 Mac 版（6.9.9 至 6.9.17，以及 5.9.17） | **FFmpeg 8.1.2**、**FriBidi 1.0.16**、libass、FreeType、HarfBuzz、libunibreak、libpng（均未修改） | 独立的 `ffmpeg`、`ffprobe` 程序 |

每个目录的 README 写明了确切的源码版本与哈希、配置参数、重新构建和替换的方法，
以及无法锁定的部分。

每个 Release 只覆盖它那一行列出的库；“应用版本”一列说明哪些构建包含这些库。

更早的 Mac 构建都是内部构建，从未对外发布，因此不需要对应的 Release。其中包括
6.9.1 至 6.9.8（2026-07-31 至 2026-08-10，附带的是另一套 ffmpeg / ffprobe 工具），
以及所有使用 2026-09-24 之前播放核心库构建的版本，即 2026-08-11 至 2026-09-23
之间的全部构建（6.9.9 至 6.9.17，以及 2026-09-24 之前构建的 5.9.17）。表中的
Mac 构建只有 2026-09-24 及之后的构建对外发布过。

### 获取源码

在 [Releases 页面](https://github.com/imranulhSH/lgpl-sources/releases) 打开对应版本。
每个 Release 包含：上游源码包（与构建时使用的完全一致）、`<标签>-patches.tar.gz`
（补丁与修改说明，无修改时没有）、`<标签>-patched-sources.tar.xz`（打完补丁后实际
编译的源码树，无修改时没有）、`<标签>-build-scripts-and-records.tar.gz`（本仓库中
对应的目录，不含 `release-assets.sha256`）以及 `SHA256SUMS`。下载后用 `shasum -a 256 -c SHA256SUMS` 校验。

### 重新构建

都需要装有 Xcode 的 Mac。各目录的 `build/` 保留了脚本在我们仓库中的目录结构，可以
直接运行，具体命令见各目录 README。这些 Release 中的构建脚本默认使用 `full`
配置，会加入 FFmpeg 视为 GPL 的库（播放核心从 `ebfc8a0` 起默认改为 `base`）；
应用使用的是 `base` 配置，本仓库的说明都设置了 `base`，如需重建与应用一致的版本，
请不要使用 `full`。

### 在应用中替换库

- **iPhone 与 iPad**：两个库都是动态框架。做一个同名、同 install name、导出相同
  符号（各目录列出了应用用到的符号）的框架，放进应用的 `Frameworks` 目录，再用你
  自己的开发者证书和包含你设备的描述文件重新签名。iOS 只运行 Apple 或此类证书签名
  的代码，App Store 安装的副本经过加密并由 Apple 签名，因此无法在未改动的设备上
  替换 App Store 安装中的框架；上述步骤只适用于你自己能够签名安装的应用副本。
- **Mac 的 ffmpeg / ffprobe**：独立程序，位于 `Contents/Resources/PlaybackTools/`，
  替换为你自己的构建后重新签名应用即可。
- **Mac 播放核心中的库（artifact 2026.10.09.1 及之后）**：这些库是一个动态框架
  `Contents/Frameworks/NsuratorPlayerCoreFFmpegRuntime.framework`。构建同名、同
  install name 的框架替换它，然后重新签名框架、解码辅助进程和应用，命令和签名
  要求见该目录 README。
- **Mac 播放核心中的库（artifact 2026.09.24.1）**：静态链接进应用和解码辅助进程，
  重新链接需要应用的目标文件，本仓库不包含这些文件。获取方式见
  https://www.nsurator.com/support.html#oss 。

在 Mac 上，重新签名的副本不再带有 Mac App Store 签名，内购、与开发者团队绑定的
数据容器和 App Group 可能无法使用。

### 许可证

各组件目录中有该组件源码自带的许可证全文。我们的补丁修改的是 LGPL-2.1-or-later
的库，按所修改的库的同一许可证分发；补丁本身另有声明的除外（AMSMB2 的一个补丁
新增的 Swift 文件与 AMSMB2 自己的 Swift 文件一样采用 MIT，见该目录的
`CHANGES.md`）。每个被修改的组件都有 `CHANGES.md`，列出修改过的文件和日期。为了让
补丁与实际构建时完全一致，被修改的源文件里没有另加带日期的说明，每个文件的修改
说明和日期都写在所属组件的 `CHANGES.md` 中。

我们自己编写的文件（从我们仓库复制的构建脚本和构建记录、各 README 和修改说明）
按 GNU 宽通用公共许可证 2.1 版或（由你选择）任何更新版本授权，与它们所构建的库
相同，全文见 [`LICENSE`](LICENSE)。文件中自带许可声明的以其声明为准；第三方文件
（许可证全文、上游构建清单）沿用其来源项目的许可证。

### 联系方式

见 https://www.nsurator.com/support.html#oss 。
