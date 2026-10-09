# Privacy metadata amendment, 2026-09-30

The source privacy manifest and both packaged slices now also declare file timestamp reason `C617.1` for opening and inspecting app-owned managed media and staging files. `3B52.1` remains for user-granted external media. This follows Apple's [required-reason API descriptions](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api). No tracking or collected-data declaration was added. This is a manifest-only amendment: both Mach-O hashes, headers, dependencies, minimum OS and ABI are unchanged. Only the manifest hashes in the reviewed lock change; the semantic auditor independently requires both reasons, including when a manifest hash is updated.

# Runtime revision: software AV1, 2026-09-30

Adds pinned [dav1d 1.5.4](https://download.videolan.org/pub/videolan/dav1d/1.5.4/) (BSD-2-Clause) to the following unchanged FFmpeg/libbluray source baseline. The official archive SHA-256 is `686616b7c69eb88d44459391ab25cac13b6647a3b288835c5784e71c1514a5c5`; its license is retained in `Licenses/dav1d-COPYING`. `rebuild-ios-ffmpeg-runtime.sh` reproduces the dependency and uses explicit `--enable-libdav1d` in the base FFmpeg profile. GPL/nonfree/version3 remain disabled. Both iOS 17 arm64 slices include the actual `_ff_libdav1d_decoder`, `_dav1d_open` and `_dav1d_version` implementations, audited together with prior capabilities.

The former AV1 descriptor alone proved insufficient: a generated 64×64 AV1 file failed with `Failed to get pixel format`, code -78, on a host without an accepted hardware route. The candidate decoded all five frames with libdav1d. The production C shim already prefers libdav1d for software AV1; no C-shim ABI change was necessary. Hardware support still depends on actual decoder creation and must not be inferred from this software test.

Validation before iOS publication: binary/source/license audit; 20/20 real macOS HostIO, paired subtitle, cancellation, thumbnail, conversion and frame-adjustment tests; actual output frames for 17 generated combinations covering MP4/MOV/MKV/WebM/AVI/MPEG/VOB/TS/M2TS, H.264/HEVC/AV1/VP9/MPEG-2/MPEG-4 and AAC/MP3/FLAC/PCM/AC-3/E-AC-3/DTS/TrueHD. VC-1 and real HDR/Dolby Vision profiles remain separate fixture/device gates. iOS matrix test is included in `NsuratorPhoneTests/RuntimeCodecMatrixTests.swift`; results are recorded after the integration run, not claimed here. Evidence directory: `/tmp/nsurator-av1-runtime-20260930/evidence`.

The current lock supersedes binary and header hashes in all historical sections. Original Mac application runtime is unchanged. Prior runtime is retained outside the repository at `/tmp/nsurator-av1-runtime-20260930/previous-reviewed-runtime.xcframework`.

## Previous paired-HostIO revision

# Runtime revision: paired HostIO, 2026-09-30

The active runtime is rebuilt from the same pinned FFmpeg 8.1 tarball and libbluray/libudfread commits recorded below, using Xcode 27.0 SDKs with deployment target **iOS 17.0**. Both arm64 device and simulator slices retain the original system dependencies, LGPL configuration, privacy manifest and framework install name. Historical binary hashes below are superseded by `../../../scripts/ios-ffmpeg-runtime-lock.json`.

All seven maintained FFmpeg patches are copied into `BuildProvenance/` with SHA-256 records. Besides the existing HLS, TLS, SFTP, Matroska cancellation, HTTP authentication and DNS patches, `ffmpeg-vobsub-host-io-inheritance.patch` makes VobSub's nested MPEG context inherit `io_open`, `io_close2`, `opaque` and `interrupt_callback`. Normal default file I/O is unchanged. Export `av_vpc_vobsub_host_io_patch_version()` returns 1; audit additionally requires the actual VobSub demuxer and DVD subtitle decoder exports. This changes no public libav struct or C-shim provider ABI.

Build reproduction: `../../../scripts/rebuild-ios-ffmpeg-runtime.sh /tmp/new-runtime-build` fetches exact sources, verifies the tar hash and submodule commit, builds three independent slices (macOS is only a test runtime), records configurations/licenses and stages a candidate outside the repository. `stage-ios-ffmpeg-candidate.py` records candidate hashes and runs complete binary audits; candidate creation is not publication approval. The existing safe production packager publishes only after matching the separately reviewed lock, retaining the prior runtime on failure. Changing SDK or build root can change hashes and requires review again.

Validation on this host: structural audit covers actual Mach-O platform/architecture/minOS, install name, exact system dependencies, header/module/privacy hashes, API and implementation exports. Real patched macOS integration: 13/13, including paired VobSub bitmap decode without files, unknown child failure, group revocation during a blocked child probe and 10 existing HostIO playback/thumbnail/seek cases (`/tmp/nsurator-paired-real-core-tests-r3.log`). Final C/registry/patch tests: 22/22 including AddressSanitizer child ownership/cancellation contracts (`/tmp/nsurator-paired-core-tests-r4.log`). Actual iOS 27 encrypted IDX/SUB and SRT App tests: 2/2 in `managed-goal-protocol-paired-ios27-r24.xcresult`, reported by the app integration owner; unrelated source tests in that run failed separately. Details are in `docs/development/player-host-io.md`.

The source tarball SHA remains `b072aed6871998cce9b36e7774033105ca29e33632be5b6347f3206898e0756a`. FFmpeg config has GPL, nonfree and version3 disabled; no new third-party codec library is added. Existing `Artifacts/Licenses` and source/relink instructions remain applicable.

## Historical initial packaging record

# iOS FFmpeg runtime provenance

This XCFramework is a dynamic packaging of the libraries consumed by
`VisionPlayerCoreFFmpegShim`. It is not a second playback engine.

## Source lock

| Component | Exact source | Integrity |
| --- | --- | --- |
| vision-player-core | Git commit `90d2c25c1fed650937431db13ae4c29d8beb53a5` | local package checkout |
| FFmpeg | official `ffmpeg-8.1.tar.xz` from `https://ffmpeg.org/releases/` | SHA-256 `b072aed6871998cce9b36e7774033105ca29e33632be5b6347f3206898e0756a` |
| libbluray | VideoLAN Git tag `1.4.1`, commit `7d94f2660af5bfc16015291a03539329135c18f1` | patch below |
| libudfread | submodule commit `139a2194525f2745b98a98e4d8fa627d07440176` | recorded by libbluray submodule |

The core build script applies the compatibility changes captured in
`BuildProvenance/libbluray-vpc-ios.patch` (SHA-256
`368d8ab1a34713be8f333bcbc3cb31ef02fee36a21ba36b9aaeb0b3b68a67cc7`).
The exact generated configure records for both slices are stored beside that
patch as `ffmpeg-*-config.mak`.

## Build profile

- Xcode 26.5 Apple clang 21, minimum iOS 17.0.
- Core script: `scripts/build-ffmpeg-apple.sh` from the locked core revision.
- Requested slices: `iphoneos-arm64 iphonesimulator-arm64`.
- Link profile: `base`; optional SMB2, SFTP, NFS, SRT, RIST and DVD navigation
  dependency bundles were not supplied.
- FFmpeg libraries: avformat, avcodec, avutil, swresample and swscale.
- Apple integration: VideoToolbox and SecureTransport.
- libbluray and libudfread are included; encrypted-disc key circumvention
  libraries are not included.
- `CONFIG_GPL=0`, `CONFIG_NONFREE=0`, `CONFIG_VERSION3=0` in both builds.

The verified static slices emitted by the core build script were packaged into
a replaceable dynamic framework by
`../../../scripts/package-ios-ffmpeg-dynamic-xcframework.sh`. Dynamic
linking keeps FFmpeg outside the application executable and follows FFmpeg's
recommended LGPL integration direction.

Each packaged framework slice also contains `PrivacyInfo.xcprivacy`. The
runtime imports the required-reason file timestamp APIs `stat`, `fstat`, and
`lstat` while opening user-selected media, so the framework
declares Apple reason `3B52.1` for explicit picker/bookmark media and disc
paths. The packaging script copies the same checked-in manifest into every
generated slice. This metadata does not alter either framework binary or the
checksums below.

## Delivered binary checksums

| Slice | SHA-256 |
| --- | --- |
| `ios-arm64` framework binary | `2bd256d0d84ab3d6a58653c2861c3e7dbc01e3048c9eeee387c113bc628d64c1` |
| `ios-arm64-simulator` framework binary | `39c20e7a7a67804dcea1e88ffe080d6d2b80f2c49b0fe6c1ff1adb8b6bd5449e` |

## Distribution requirement

Before public distribution, publish an archive containing the exact FFmpeg,
libbluray and libudfread sources above, the compatibility patch and these build
records at a durable URL controlled by the distributor. Put that URL in the
product download page and App Store support/legal material. The licenses are
included in the App bundle under Settings → Privacy.

This record is engineering evidence, not legal advice; the distributing entity
must approve the final LGPL compliance package and written offer.
