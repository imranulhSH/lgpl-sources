# Replacing the Runtime Framework

This artifact links FFmpeg, libbluray (with libudfread), and dav1d dynamically. The
consuming app loads them from one framework in its bundle:

- `macosx-arm64`: `Contents/Frameworks/NsuratorPlayerCoreFFmpegRuntime.framework`, install name `@rpath/NsuratorPlayerCoreFFmpegRuntime.framework/Versions/A/NsuratorPlayerCoreFFmpegRuntime`, UUID `58BB2D7D-52C4-3BC0-9CD2-5C811162D69A`.

The framework is built from the static archives under `install/` and
`dependencies/`, each force-loaded unchanged, by
`scripts/package-apple-ffmpeg-runtime-framework.sh`. The exact link command, the
archive checksums, and the toolchain are in `../relink-materials-manifest/`.

To run the app with modified libraries:

1. Verify each archive against `../source-offer/SOURCE-CODE.md`, extract it, and
   apply your changes.
2. Rebuild the matching Apple slice with `scripts/build-ffmpeg-apple.sh` and the
   source directory variables documented by that script. Preserve the manifest's
   configure flags so the app finds the functions it calls.
3. Package the framework: `scripts/package-apple-ffmpeg-runtime-framework.sh --build
   --ffmpeg-prefix <install>/<slice> --dependency-prefix <dependencies>/<slice>
   --output-dir <dir>`. Keep the framework name and install name.
4. Replace the framework inside the app bundle and sign the bundle again, inner code
   first: the framework, then the decoder helper XPC service, then the app. Sign all
   three with one identity, or ad hoc with the
   `com.apple.security.cs.disable-library-validation` entitlement on the app and the
   helper; leave out entitlements that need a provisioning profile.

The app needs no relinking: it binds to the framework's exported symbols at launch.
