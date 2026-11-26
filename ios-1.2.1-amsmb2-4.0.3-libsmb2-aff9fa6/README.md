# iPhone and iPad app 1.2.1: AMSMB2 and libsmb2

> **From build 156 on, replaced by [`ios-1.2.1-156-amsmb2-4.0.3-libsmb2-aff9fa6`](https://github.com/imranulhSH/lgpl-sources/releases/tag/ios-1.2.1-156-amsmb2-4.0.3-libsmb2-aff9fa6).**
> This release covers Nsuve for iPhone and iPad 1.2.1, builds 136 to 155. The
> new one has the same upstream archives and patches 0001 to 0004, and adds
> AMSMB2 patch 0005 (2026-11-26): every SMB connection is made and destroyed
> under one lock, so connections opened and closed on several threads at once
> no longer break libsmb2's list of them. Apart from this note, this folder and
> the release's assets are as published on 2026-11-23.
>
> **从 156 号构建起由 [`ios-1.2.1-156-amsmb2-4.0.3-libsmb2-aff9fa6`](https://github.com/imranulhSH/lgpl-sources/releases/tag/ios-1.2.1-156-amsmb2-4.0.3-libsmb2-aff9fa6) 接替。**
> 本 Release 对应 Nsuve iPhone/iPad 1.2.1 的 136 至 155 号构建。新版的上游源码包和补丁
> 0001–0004 都相同，另加 AMSMB2 补丁 0005（2026-11-26）：建、拆每条 SMB 连接都排同一把锁，
> 多个线程同时开关连接不会再弄乱 libsmb2 的连接表。除这段说明外，本目录和 Release 的附件
> 保持 2026-11-23 发布时的样子。

Release tag: `ios-1.2.1-amsmb2-4.0.3-libsmb2-aff9fa6`

This folder and its release are the corresponding source for
`AMSMB2.framework`, the SMB file-sharing library inside Nsuve (formerly
Nsurator) for iPhone and iPad 1.2.1, from build 136 on.

## Which app builds use it

Nsuve for iPhone and iPad 1.2.1, from build 136 on, including 1.2.1 (155).
Build 136 (2026-11-14) was the first with patch 0004. The upstream sources and
patches 0001 to 0003 are the same as in release
`ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6`, which covers the builds before 136,
earlier 1.2.1 builds included: they do not have patch 0004.

## The shipped binary

| | |
|---|---|
| Path in the app | `NsuratorPhone.app/Frameworks/AMSMB2.framework/AMSMB2` |
| Linking | Dynamic framework, install name `@rpath/AMSMB2.framework/AMSMB2`. Xcode builds it from source while archiving the app, as the SwiftPM product `AMSMB2` (`type: .dynamic` in `build/Package.swift`). |
| Contains | libsmb2 (C) and the AMSMB2 Swift wrapper, with our changes. No other app code. |

## Components

| Component | Licence | Upstream | Release asset | SHA-256 |
|---|---|---|---|---|
| AMSMB2, commit `1726aaaf7adf63d7d1d2a0c5d1b0e635028215c0` (tag `4.0.3`) | The repository's `LICENSE` is LGPL-2.1. The Swift files say MIT, and the upstream README says that because libsmb2 is linked in, the project as a whole is LGPL-2.1 and must be linked dynamically. We treat it as LGPL-2.1. | https://github.com/amosavian/AMSMB2 | `AMSMB2-1726aaaf7adf63d7d1d2a0c5d1b0e635028215c0.tar.gz` | `730f8311bd62c80e0ae3e2743f296a281ddb52b2fc728869c92bea66f61d4a31` |
| libsmb2, commit `aff9fa6ba9f41cfd3c15d184554601ec3f6d8d03` (`git describe`: `libsmb2-6.2-110-gaff9fa6`) | `lib/` and `include/`: LGPL-2.1-or-later. `examples/`: BSD-2-Clause (not built). Some files carry their own notices (for example the RSA MD4 notice in `lib/md4c.c`). | https://github.com/sahlberg/libsmb2 | `libsmb2-aff9fa6ba9f41cfd3c15d184554601ec3f6d8d03.tar.gz` | `045cc8041a3617c4066b97e2e91a30a2d1dfc921858f4154db2a76156fb5cac6` |

AMSMB2 pins libsmb2 at that commit as a git submodule in
`Dependencies/libsmb2`. Neither project publishes an archive for these
commits, so both assets were made with `git archive` from clones of the
commits above; `git get-tar-commit-id` on the uncompressed tar prints the
commit id. They are byte for byte the archives attached to
`ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6`.

When this release was made, the upstream trees with our four patches applied
were compared file by file with the copy the app builds: they are identical,
apart from our added test programs and records and four upstream files the
build does not use (see `CHANGES.md`). That copy is the `AMSMB2/` folder of
the patched-sources archive. In the app's own repository it is the git tree
`62872ff829709f471e2ce3b058bd1ddc120018e6`; to check an unpacked copy against
that id, run `git init -q && git add -A -f && git write-tree` inside `AMSMB2/`.

## Folder contents

| Path | What it is |
|---|---|
| `patches/` | Our four patches, numbered in the order they apply: 0001 and 0003 change libsmb2, 0002 and 0004 change AMSMB2. They are LGPL-2.1-or-later, except the new Swift file that 0002 adds, which is MIT like AMSMB2's own Swift files (see `CHANGES.md`) |
| `CHANGES.md` | Dated change notices |
| `amsmb2/LICENSE`, `libsmb2/COPYING`, `libsmb2/LICENCE-LGPL-2.1.txt` | Licence texts from the upstream sources |
| `build/Package.swift`, `build/Package@swift-6.0.swift` | The SwiftPM manifests the app builds with. They are upstream's, unchanged. |
| `build/UPSTREAM.json`, `build/UPSTREAM.md` | Our vendoring record: upstream commits and the hashes of every changed file before and after. `UPSTREAM.json` lists patch 0004 and the two Swift files it changes; `UPSTREAM.md` is unchanged since 1.0.1 and describes patches 0001 to 0003 |
| `records/app-imports-from-AMSMB2.txt` | The Swift symbols the app imports from the framework, taken from a Debug simulator build of app commit `651a86a5`, the one that links this release. They are the same 11 symbols as in 1.0.1: patch 0004 does not change the public Swift interface. |
| `release-assets.sha256` | SHA-256 of every file attached to the release |

## Rebuilding

Unpack `ios-1.2.1-amsmb2-4.0.3-libsmb2-aff9fa6-patched-sources.tar.xz`. Its
`AMSMB2/` folder is the package exactly as the app builds it. Build the
framework with Xcode for iOS:

```sh
tar -xJf ios-1.2.1-amsmb2-4.0.3-libsmb2-aff9fa6-patched-sources.tar.xz
cd ios-1.2.1-amsmb2-4.0.3-libsmb2-aff9fa6-patched-sources/AMSMB2
xcodebuild -scheme AMSMB2 -destination 'generic/platform=iOS' -configuration Release \
  -derivedDataPath /absolute/new/directory
```

The framework is then at
`Build/Products/Release-iphoneos/PackageFrameworks/AMSMB2.framework` in that
directory. On 2026-11-23 these commands were run on the release assets with
Xcode 27.1 (27A9275). They built an arm64 `AMSMB2.framework` with install name
`@rpath/AMSMB2.framework/AMSMB2` that exports every symbol in
`records/app-imports-from-AMSMB2.txt`.

Or start from the upstream archives: put the libsmb2 tree in AMSMB2's
`Dependencies/libsmb2` and apply `patches/` in order with `patch -p1`.

## Replacing the framework in the app

A replacement must be a dynamic framework named `AMSMB2.framework` with
install name `@rpath/AMSMB2.framework/AMSMB2`, built for arm64 iOS with a
deployment target of iOS 17.0 or lower (the app's own target), that provides
every symbol in `records/app-imports-from-AMSMB2.txt`. These are Swift
symbols, so the replacement must keep the same public Swift API and type
layout and should be built with the same Swift compiler version; the safest
change is one that does not touch the public Swift interface.

Put it in place of `Frameworks/AMSMB2.framework`, then sign the framework and
the app again with your own certificate and a provisioning profile that
includes your device, and install with Xcode or `xcrun devicectl`.

What iOS allows: iOS runs only code signed by Apple or by a developer
certificate whose provisioning profile includes the device. Copies of the app
installed from the App Store are encrypted and signed by Apple, so a framework
cannot be replaced inside an App Store installation on an unmodified device.
The steps above work only for a copy of the app that you are able to sign and
install yourself.

## What we could not pin

- Xcode compiles `AMSMB2.framework` from these sources while it archives the
  app, so the shipped framework's hash is not listed here. When this release
  was prepared (2026-11-23), the Mac that builds the app had Xcode 27.1
  (27A9275) with Apple Swift 6.4 (swiftlang-6.4.0.34.1).
- The sources themselves are pinned exactly: upstream by git commit, and the
  copy the app builds by the git tree id above.

## 中文说明

本目录和同名 Release 是 Nsuve（原 Nsurator）iPhone/iPad 1.2.1 从 136 号构建起（含
1.2.1（155））中 `AMSMB2.framework`（动态链接框架，打包应用时由 Xcode 从源码构建）的
对应源码。136 号构建（2026-11-14）是第一个带补丁 0004 的构建；在它之前的构建（包括
1.2.1 的早期构建）没有补丁 0004，对应 `ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6`。

- 框架包含 libsmb2（LGPL-2.1-or-later）和 AMSMB2 Swift 封装（上游说明整体按
  LGPL-2.1 处理）。上游版本：AMSMB2 提交 `1726aaa`（4.0.3），libsmb2 提交 `aff9fa6`。
  两个上游源码包与 1.0.1 的 Release 逐字节相同。
- 我们的 4 个补丁（libsmb2 两个：0001、0003；AMSMB2 两个：0002、0004）和新增的两个
  测试程序见 `patches/` 与 `CHANGES.md`。0001–0003 与 1.0.1 相同；0004（2026-11-14）
  修改 `AMSMB2/Context.swift` 和 `AMSMB2/FileHandle.swift`：libsmb2 已经释放的文件句柄
  不再被读取、关闭或使用；客户端对象释放时不再自己另发一次断开共享的请求。
- 上游加补丁后的源码树与应用实际编译的副本逐文件比对一致。该副本即补丁后源码包里的
  `AMSMB2/` 目录，在应用仓库中是 git tree `62872ff829709f471e2ce3b058bd1ddc120018e6`，
  可在解开的 `AMSMB2/` 中运行 `git init -q && git add -A -f && git write-tree` 核对。
- 补丁按所修改的库的许可证（LGPL-2.1-or-later）分发；补丁 0002 新增的
  `AMSMB2/ReadOnlyFile.swift` 与 AMSMB2 自己的 Swift 文件一样采用 MIT，作为整体按
  LGPL-2.1 分发的 AMSMB2 框架的一部分发布。
- 重新构建：解开补丁后的源码包，在其中的 `AMSMB2/` 目录按上面的 `xcodebuild` 命令
  构建。2026-11-23 用 Xcode 27.1 按此方法从 Release 附件构建成功，得到的框架导出
  `records/app-imports-from-AMSMB2.txt` 中的全部符号。
- 替换：做一个同名、同 install name、提供 `records/app-imports-from-AMSMB2.txt`
  中全部符号的动态框架（Swift 公开接口和类型布局需保持一致，最好用同一版本的
  Swift 编译器），放进应用并用你自己的证书和描述文件重新签名安装。App Store 安装
  的副本经过加密和 Apple 签名，无法在未改动的设备上直接替换。
- 无法锁定的部分：框架在打包应用时才编译，因此这里不列发布版框架的哈希。准备本
  Release 时（2026-11-23），构建应用的 Mac 使用 Xcode 27.1（27A9275）和 Apple Swift 6.4。
