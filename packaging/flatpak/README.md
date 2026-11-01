# Flatpak

`com.dhivalabs.creator_toolkit.yml` packages Creator Toolkit as a Flatpak on
the GNOME 51 runtime, with its own FFmpeg. The app module repackages the
installed tree CI stages from the release bundle
(`packaging/linux-distros/stage-tree.sh`), so the Flatpak runs the same
binary as the tarball and every other Linux format.

## FFmpeg

The video and audio tools and WEBP output run the `ffmpeg` and `ffprobe`
programs. The runtime's FFmpeg leaves out the patented codecs (no H.264 or
HEVC decoding, no x264 encoding), and the codecs-extra extension (formerly
ffmpeg-full) has libraries only, no programs. So the manifest builds:

- nasm 2.16.03 (x86_64 only, build tool, not shipped);
- x264 (stable branch, shared library);
- FFmpeg 9.0.2 with all its decoders and `--enable-gpl --enable-libx264
  --enable-libmp3lame --enable-libvpx --enable-libopus --enable-libvorbis
  --enable-libwebp` (LAME, libvpx, Opus, Vorbis and libwebp come from the
  runtime). `ffmpeg` and `ffprobe` land in `/app/bin`, ahead of anything else
  on PATH.

That FFmpeg is GPL-2.0-or-later because of x264. Whoever distributes the
bundle must also make the corresponding sources available: the URLs and
commits pinned in the manifest are those sources, and a Flathub build
publishes them automatically. (H.264 is also patent-encumbered in some
countries; Flathub accepts x264 in apps, but the user decides.)

## How CI builds it

The `flatpak` job in `.github/workflows/desktop.yml`, on x86_64 and aarch64:

1. takes the staged tree from the `distros` job and unpacks it into
   `packaging/flatpak/tree/` (ignored by git);
2. builds the manifest with `flatpak/flatpak-github-actions/flatpak-builder`
   in Flathub's builder image (FFmpeg takes most of the time) and exports
   `creator-toolkit-<version>-<arch>.flatpak`, with Flathub as the runtime
   repo;
3. runs `smoke.sh`: installs the bundle with `flatpak install --user`, runs
   ldd on every ELF file inside the sandbox, runs every FFmpeg argument set
   the app uses (H.264/AAC MP4 and MKV, VP9/Opus WEBM, GIF, stream-copy trim,
   MP3, M4A, OGG, WAV, FLAC, WEBP, and ffprobe's duration) on a generated
   H.264 clip inside the sandbox, writing to `~/CreatorToolkit`, checks the
   files on the host side, and starts the app and checks that it drew its
   window (colours in Xvfb's framebuffer, `xwd-colours.py`).

Install with:

```sh
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user ./creator-toolkit-<version>-<arch>.flatpak
flatpak run com.dhivalabs.creator_toolkit
```

## Permissions

- `--filesystem=~/CreatorToolkit:create`: the output folder, as on every
  other build.
- Input files come through the file chooser portal (`file_picker` talks to
  `org.freedesktop.portal.FileChooser`) or drag and drop, both of which give
  the sandbox the files the user picked. No network.

## Submitting to Flathub

Not done; the user decides. Differences for a Flathub submission:

- the `tree` dir source becomes the release tarball of each architecture (a
  `type: archive` source with `only-arches`, url and sha256) plus the
  desktop entry and icons from `linux/packaging/`, or a build from source
  with the Flutter SDK as a module;
- the repository needs a licence (the metainfo says
  `LicenseRef-proprietary`, as there is none), `<releases>` must list each
  new version, and Flathub wants screenshots.
