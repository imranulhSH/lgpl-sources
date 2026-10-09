# Bundled FFmpeg command-line media tools

Nsurator bundles separate `ffmpeg` and `ffprobe` executables for screenshots,
GIF and clip export, thumbnail generation, media probing, and remote-playback
transcoding. They are launched as child processes and are not loaded into the
Nsurator process.

The bundled macOS arm64 tools are built from FFmpeg 8.1.2 source under the GNU
Lesser General Public License, version 2.1 or later. The build explicitly
disables FFmpeg GPL and nonfree components and does not include the libx264 or
libx265 encoders. H.264 export and remote-playback transcoding use Apple's
VideoToolbox encoder.

Subtitle rendering is provided by statically linked LGPL or permissively
licensed dependencies: libass, FreeType, FriBidi, HarfBuzz, libunibreak, and
libpng. The exact versions, source URLs, and source hashes are recorded in
`Config/media-tools-sources.json`. The release artifact includes the complete
source archives, build configuration, relink script, and license texts.

Packaging verifies the pinned binary hashes, arm64 architecture, macOS 14.0
deployment target, system-only dynamic dependencies, required filters and
encoders, absence of libx264/libx265, and the LGPL-only FFmpeg configuration.

Source references:

- https://ffmpeg.org/
- https://github.com/libass/libass
- https://freetype.org/
- https://github.com/fribidi/fribidi
- https://github.com/harfbuzz/harfbuzz
- https://github.com/adah1972/libunibreak
- http://www.libpng.org/pub/png/libpng.html
