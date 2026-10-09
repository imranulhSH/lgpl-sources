# iPhone and iPad app 1.0.1 (101): AMSMB2 and libsmb2

Release tag: `ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6`

This folder and its release are the corresponding source for
`AMSMB2.framework`, the SMB file-sharing library inside Nsurator for iPhone
and iPad 1.0.1 (build 101).

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
commits, so both assets were made with `git archive` from clones checked out
at the commits above; `git get-tar-commit-id` on the uncompressed tar prints
the commit id.

When this release was made, the upstream trees with our three patches applied
were compared file by file with the copy the app builds: they are identical,
apart from our added test programs and records and four upstream files the
build does not use (see `CHANGES.md`).

## Folder contents

| Path | What it is |
|---|---|
| `patches/` | Our three patches, numbered in the order they apply. They are LGPL-2.1-or-later, except the new Swift file that 0002 adds, which is MIT like AMSMB2's own Swift files (see `CHANGES.md`) |
| `CHANGES.md` | Dated change notices |
| `amsmb2/LICENSE`, `libsmb2/COPYING`, `libsmb2/LICENCE-LGPL-2.1.txt` | Licence texts from the upstream sources |
| `build/Package.swift`, `build/Package@swift-6.0.swift` | The SwiftPM manifests the app builds with. They are upstream's, unchanged. |
| `build/UPSTREAM.json`, `build/UPSTREAM.md` | Our vendoring record: upstream commits and the hashes of every changed file before and after |
| `records/app-imports-from-AMSMB2.txt` | The Swift symbols the app imports from the framework (taken from a Debug simulator build of the same app commit) |
| `release-assets.sha256` | SHA-256 of every file attached to the release |

## Rebuilding

Unpack `ios-1.0.1-amsmb2-4.0.3-libsmb2-aff9fa6-patched-sources.tar.xz`. It
holds the `AMSMB2/` package exactly as the app builds it. Build the framework
with Xcode for iOS, for example:

```sh
cd AMSMB2
xcodebuild -scheme AMSMB2 -destination 'generic/platform=iOS' -configuration Release \
  -derivedDataPath /absolute/new/directory
```

Or start from the upstream archives: put the libsmb2 tree in AMSMB2's
`Dependencies/libsmb2` and apply `patches/` in order with `patch -p1`.

The toolchain that built the shipped `AMSMB2.framework` for 1.0.1 was not
recorded (see below).

## Replacing the framework in the app

A replacement must be a dynamic framework named `AMSMB2.framework` with
install name `@rpath/AMSMB2.framework/AMSMB2`, built for arm64 iOS with a
deployment target of iOS 17.0 or lower (the app's own target), that provides every symbol in `records/app-imports-from-AMSMB2.txt`.
These are Swift symbols, so the replacement must keep the same public Swift
API and type layout and should be built with the same Swift compiler version;
the safest change is one that does not touch the public Swift interface.

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

- The Xcode and Swift versions that built the shipped `AMSMB2.framework` for
  1.0.1 (101) were not recorded, and no archive record of that build exists
  yet, so the framework's hash is not listed here.
- The sources themselves are pinned exactly by git commit.

## 中文说明

本目录和同名 Release 是 Nsurator iPhone/iPad 1.0.1（101）中
`AMSMB2.framework`（动态链接框架，打包应用时由 Xcode 从源码构建）的对应源码。

- 框架包含 libsmb2（LGPL-2.1-or-later）和 AMSMB2 Swift 封装（上游说明整体按
  LGPL-2.1 处理）。上游版本：AMSMB2 提交 `1726aaa`（4.0.3），libsmb2 提交 `aff9fa6`。
- 我们的 3 个补丁和新增的两个测试程序见 `patches/` 与 `CHANGES.md`。上游加补丁后的
  源码树与应用实际编译的副本逐文件比对一致。补丁 0002 新增的
  `AMSMB2/ReadOnlyFile.swift` 与 AMSMB2 自己的 Swift 文件一样采用 MIT，作为整体按
  LGPL-2.1 分发的 AMSMB2 框架的一部分发布；其余补丁按所修改的库的许可证
  （LGPL-2.1-or-later）分发。
- 替换：做一个同名、同 install name、提供 `records/app-imports-from-AMSMB2.txt`
  中全部符号的动态框架（Swift 公开接口和类型布局需保持一致，最好用同一版本的
  Swift 编译器），放进应用并用你自己的证书和描述文件重新签名安装。App Store 安装
  的副本经过加密和 Apple 签名，无法在未改动的设备上直接替换。
- 无法锁定的部分：构建 1.0.1 版 `AMSMB2.framework` 的 Xcode/Swift 版本没有记录。
