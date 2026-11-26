# iPhone and iPad app 1.2.1 from build 156, and Apple Vision Pro: AMSMB2 and libsmb2

Release tag: `ios-1.2.1-156-amsmb2-4.0.3-libsmb2-aff9fa6`

This folder and its release are the corresponding source for
`AMSMB2.framework`, the SMB file-sharing library inside Nsuve (formerly
Nsurator) for iPhone and iPad 1.2.1 from build 156 on, and inside Nsuve for
Apple Vision Pro.

## Which app builds use it

- Nsuve for iPhone and iPad 1.2.1, from build 156 on. Build 156 (2026-11-26)
  is the first with patch 0005. Builds 136 to 155 carry the sources of
  `ios-1.2.1-amsmb2-4.0.3-libsmb2-aff9fa6` (patches 0001 to 0004), and the
  builds before 136 those of `ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6`
  (patches 0001 to 0003).
- Nsuve for Apple Vision Pro, from its first distributed build: the same
  package and the same five patches, built for visionOS. The Apple Vision Pro
  app vendors the same vendoring record (`build/UPSTREAM.json`), and the
  package in the patched-sources archive builds for visionOS unchanged.

## The shipped binary

| | |
|---|---|
| Path in the iPhone and iPad app | `NsuratorPhone.app/Frameworks/AMSMB2.framework/AMSMB2` |
| Linking | Dynamic framework, install name `@rpath/AMSMB2.framework/AMSMB2`. Xcode builds it from source while archiving the app, as the SwiftPM product `AMSMB2` (`type: .dynamic` in `build/Package.swift`). The Apple Vision Pro app links the same framework, built for visionOS. |
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
commit id. They are byte for byte the archives attached to the two earlier
AMSMB2 releases.

When this release was made, the upstream trees with our five patches applied
were compared file by file with the copy the iPhone and iPad app builds: they
are identical, apart from our added test programs and records and four
upstream files the build does not use (see `CHANGES.md`). That copy is the
`AMSMB2/` folder of the patched-sources archive. In the app's own repository it
is the git tree `d4cbc198d018651015e13ac11841af275c74f7fe`; to check an unpacked copy against that id, run
`git init -q && git add -A -f && git write-tree` inside `AMSMB2/`.

## Folder contents

| Path | What it is |
|---|---|
| `patches/` | Our five patches, numbered in the order they apply: 0001 and 0003 change libsmb2, 0002, 0004 and 0005 change AMSMB2. They are LGPL-2.1-or-later, except the new Swift file that 0002 adds, which is MIT like AMSMB2's own Swift files (see `CHANGES.md`) |
| `CHANGES.md` | Dated change notices |
| `amsmb2/LICENSE`, `libsmb2/COPYING`, `libsmb2/LICENCE-LGPL-2.1.txt` | Licence texts from the upstream sources |
| `build/Package.swift`, `build/Package@swift-6.0.swift` | The SwiftPM manifests the iPhone and iPad app builds with. They are upstream's, unchanged. |
| `build/UPSTREAM.json`, `build/UPSTREAM.md` | Our vendoring record: upstream commits and the hashes of every changed file before and after. `UPSTREAM.json` lists patches 0004 and 0005 and the Swift files they change; `UPSTREAM.md` is unchanged since 1.0.1 and describes patches 0001 to 0003 |
| `records/app-imports-from-AMSMB2.txt` | The Swift symbols the iPhone and iPad app imports from the framework, taken from a Debug simulator build of app commit `617bb753`, the one that links this release. They are the same 11 symbols as before: patch 0005 does not change the public Swift interface. |
| `release-assets.sha256` | SHA-256 of every file attached to the release |

## Rebuilding

Unpack `ios-1.2.1-156-amsmb2-4.0.3-libsmb2-aff9fa6-patched-sources.tar.xz`.
Its `AMSMB2/` folder is the package exactly as the iPhone and iPad app builds
it. Build the framework with Xcode for iOS:

```sh
tar -xJf ios-1.2.1-156-amsmb2-4.0.3-libsmb2-aff9fa6-patched-sources.tar.xz
cd ios-1.2.1-156-amsmb2-4.0.3-libsmb2-aff9fa6-patched-sources/AMSMB2
xcodebuild -scheme AMSMB2 -destination 'generic/platform=iOS' -configuration Release \
  -derivedDataPath /absolute/new/directory
```

The framework is then at
`Build/Products/Release-iphoneos/PackageFrameworks/AMSMB2.framework` in that
directory. On 2026-11-26 these commands were run on the release assets with
Xcode 27.1 (27A9275). They built an arm64 `AMSMB2.framework` with install name
`@rpath/AMSMB2.framework/AMSMB2` that exports every symbol in
`records/app-imports-from-AMSMB2.txt`.

For Apple Vision Pro, build the same package with
`-destination 'generic/platform=visionOS'`; the framework is then at
`Build/Products/Release-xros/PackageFrameworks/AMSMB2.framework`. On 2026-11-26
this built an arm64 visionOS `AMSMB2.framework` with the same install name from
the release assets (visionOS SDK 27.0), with no change to the package.

Or start from the upstream archives: put the libsmb2 tree in AMSMB2's
`Dependencies/libsmb2` and apply `patches/` in order with `patch -p1`.

## Replacing the framework in the app

A replacement must be a dynamic framework named `AMSMB2.framework` with
install name `@rpath/AMSMB2.framework/AMSMB2`, built for arm64 iOS with a
deployment target of iOS 17.0 or lower (the iPhone and iPad app's own target),
or for arm64 visionOS for the Apple Vision Pro app, that provides every symbol
the app imports (for the iPhone and iPad app, `records/app-imports-from-AMSMB2.txt`).
These are Swift symbols, so the replacement must keep the same public Swift
API and type layout and should be built with the same Swift compiler version;
the safest change is one that does not touch the public Swift interface.

Put it in place of `Frameworks/AMSMB2.framework`, then sign the framework and
the app again with your own certificate and a provisioning profile that
includes your device, and install with Xcode or `xcrun devicectl`.

What iOS and visionOS allow: they run only code signed by Apple or by a
developer certificate whose provisioning profile includes the device. Copies
of the app installed from the App Store are encrypted and signed by Apple, so
a framework cannot be replaced inside an App Store installation on an
unmodified device. The steps above work only for a copy of the app that you
are able to sign and install yourself.

## What we could not pin

- Xcode compiles `AMSMB2.framework` from these sources while it archives the
  app, so the shipped framework's hash is not listed here. When this release
  was prepared (2026-11-26), the Mac that builds the iPhone and iPad app had
  Xcode 27.1 (27A9275) with Apple Swift 6.4 (swiftlang-6.4.0.34.1).
- The Apple Vision Pro app is built on another Mac; its Xcode version and the
  symbols it imports from the framework are not recorded here.
- The sources themselves are pinned exactly: upstream by git commit, and the
  copy the iPhone and iPad app builds by the git tree id above.

## 中文说明

本目录和同名 Release 是 Nsuve（原 Nsurator）iPhone/iPad 1.2.1 从 156 号构建起，以及
Nsuve Apple Vision Pro 版中 `AMSMB2.framework`（动态链接框架，打包应用时由 Xcode 从源码
构建）的对应源码。156 号构建（2026-11-26）是第一个带补丁 0005 的构建；136 至 155 号构建
对应 `ios-1.2.1-amsmb2-4.0.3-libsmb2-aff9fa6`（补丁 0001–0004），136 号之前的构建对应
`ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6`（补丁 0001–0003）。Apple Vision Pro 版从第一个对外
发布的构建起用的也是这一份：同一个包、同样 5 个补丁、同一份 `build/UPSTREAM.json`，为 visionOS
构建；补丁后源码包里的包不用改就能为 visionOS 编译。

- 框架包含 libsmb2（LGPL-2.1-or-later）和 AMSMB2 Swift 封装（上游说明整体按
  LGPL-2.1 处理）。上游版本：AMSMB2 提交 `1726aaa`（4.0.3），libsmb2 提交 `aff9fa6`。
  两个上游源码包与之前两个 AMSMB2 Release 逐字节相同。
- 我们的 5 个补丁（libsmb2 两个：0001、0003；AMSMB2 三个：0002、0004、0005）和新增的
  两个测试程序见 `patches/` 与 `CHANGES.md`。0001–0004 与上一版相同；0005（2026-11-26）
  只改 `AMSMB2/Context.swift`：libsmb2 用一张全局链表记着所有连接，建、拆连接时增删这张表
  都不加锁；现在 AMSMB2 建连接、释放连接、出错后拆连接都排同一把进程级的锁，多个线程同时
  建、拆连接不会再把表弄乱。libsmb2 本身没有改。
- 上游加补丁后的源码树与 iPhone/iPad 应用实际编译的副本逐文件比对一致。该副本即补丁后
  源码包里的 `AMSMB2/` 目录，在应用仓库中是 git tree `d4cbc198d018651015e13ac11841af275c74f7fe`，可在解开的 `AMSMB2/` 中
  运行 `git init -q && git add -A -f && git write-tree` 核对。
- 补丁按所修改的库的许可证（LGPL-2.1-or-later）分发；补丁 0002 新增的
  `AMSMB2/ReadOnlyFile.swift` 与 AMSMB2 自己的 Swift 文件一样采用 MIT，作为整体按
  LGPL-2.1 分发的 AMSMB2 框架的一部分发布。
- 重新构建：解开补丁后的源码包，在其中的 `AMSMB2/` 目录按上面的 `xcodebuild` 命令构建；把 `-destination`
  换成 `'generic/platform=visionOS'` 即为 Apple Vision Pro 构建，包不用改。2026-11-26 用 Xcode 27.1
  按此方法从 Release 附件构建成功（iOS 和 visionOS 各一次），iOS 版导出
  `records/app-imports-from-AMSMB2.txt` 中的全部符号。
- 替换：做一个同名、同 install name、提供应用用到的全部符号（iPhone/iPad 见
  `records/app-imports-from-AMSMB2.txt`）的动态框架（Swift 公开接口和类型布局需保持一致，
  最好用同一版本的 Swift 编译器），放进应用并用你自己的证书和描述文件重新签名安装。
  App Store 安装的副本经过加密和 Apple 签名，无法在未改动的设备上直接替换。
- 无法锁定的部分：框架在打包应用时才编译，因此这里不列发布版框架的哈希。准备本 Release
  时（2026-11-26），构建 iPhone/iPad 应用的 Mac 使用 Xcode 27.1（27A9275）和 Apple
  Swift 6.4。Apple Vision Pro 版在另一台 Mac 上构建，它的 Xcode 版本和从框架导入的符号
  没有记在这里。
