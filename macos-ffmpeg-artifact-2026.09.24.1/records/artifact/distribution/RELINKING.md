# Static Relinking Instructions

This artifact uses static SwiftPM linkage. The accompanying source archives, installed
headers, static libraries, configure flags, and checksums provide the library-side inputs
for rebuilding or substituting modified third-party libraries.

1. Verify each archive against `../source-offer/SOURCE-CODE.md`, then extract it.
2. Rebuild the matching Apple slice with `scripts/build-ffmpeg-apple.sh` and the source
   directory variables documented by that script. Preserve the manifest's configure flags.
3. Replace the corresponding archives under `install/` or `dependencies/` and regenerate
   the artifact manifest and xcconfig with `--package-artifact-root`.
4. Rebuild the consuming app against the regenerated artifact and run its playback gates.

A final application distributor must retain its own application object files or equivalent
reproducible build inputs needed to relink that application; this SDK artifact cannot supply
application-specific objects. Review that final distribution against the exact licenses.
