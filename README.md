# Creator Toolkit

[![ARM64 builds](https://github.com/Dhiva-Labs/creator_toolkit/actions/workflows/desktop.yml/badge.svg?branch=main)](https://github.com/Dhiva-Labs/creator_toolkit/actions/workflows/desktop.yml)
![Linux x64 | arm64](https://img.shields.io/badge/Linux-x64%20%7C%20arm64-informational?logo=linux&logoColor=white)
![Windows x64 | arm64](https://img.shields.io/badge/Windows-x64%20%7C%20arm64-informational?logo=windows&logoColor=white)
![Linux: tar.gz | rpm | Arch | AppImage | Flatpak](https://img.shields.io/badge/Linux-tar.gz%20%7C%20rpm%20%7C%20Arch%20%7C%20AppImage%20%7C%20Flatpak-informational?logo=linux&logoColor=white)

A simple, modern Flutter app that helps content creators optimize and convert
media before sharing it online. Runs on **Linux (x64, arm64), Windows (x64,
arm64), and Android** from a single codebase, fully offline.

## Features

- **Image tools** — compress, resize, center-crop to aspect ratio, convert
  (JPG / PNG / WEBP). All tools accept batches.
- **Video tools** — compress (H.264 with quality + resolution presets),
  convert (MP4 / MKV / MOV / WEBM / GIF), trim (instant keyframe cut or
  frame-accurate re-encode).
- **Audio tools** — compress to a target bitrate, convert
  (MP3 / M4A / WAV / FLAC / OGG).
- **PDF tools** — compress, merge, split (every page or a page range).
- **Social media presets** — one-click image export sized for Instagram,
  YouTube, TikTok, and Facebook (cover-crop + quality tuning; the YouTube
  thumbnail preset stays under the 2 MB cap automatically).

Material 3 UI with light/dark/system theme, drag & drop on desktop, and live
per-job progress with before → after file sizes.

## Where results go

- **Desktop:** `~/CreatorToolkit` (a "Show in folder" button appears on each result)
- **Android:** `Android/data/com.dhivalabs.creator_toolkit/files/CreatorToolkit`

## Requirements

- **Desktop:** an `ffmpeg` binary on PATH for the video/audio tools
  (Ubuntu: `sudo apt install ffmpeg`). Image and PDF tools work without it,
  except WEBP encoding which also uses ffmpeg.
- **Android:** nothing — FFmpeg is bundled via `ffmpeg_kit_flutter_new`
  (full-gpl build: libx264, VP9, Opus, LAME, libwebp). minSdk 24.

## Download

GitHub releases carry the desktop builds, attached by the CI workflow, and
every CI run keeps them as workflow artifacts. The Android APK is not part of a
release:

| Platform      | File                                          |
|---------------|-----------------------------------------------|
| Linux x64     | `CreatorToolkit-<version>-linux-x64.tar.gz`   |
| Linux arm64   | `CreatorToolkit-<version>-linux-arm64.tar.gz` |
| Windows x64   | `CreatorToolkit-<version>-windows-x64.zip`    |
| Windows arm64 | `CreatorToolkit-<version>-windows-arm64.zip`  |

Unpack and run `creator_toolkit` (`creator_toolkit.exe` on Windows). The video
and audio tools need `ffmpeg` on PATH (Windows: for example
`winget install Gyan.FFmpeg`).

### Linux packages

From the next release on, releases also carry packages for Linux
distributions, built from the same binaries as the tarball (`x86_64` and
`aarch64`):

| Distribution | Asset | Install |
|---|---|---|
| Fedora, RHEL/Rocky/Alma | `creator-toolkit-<version>-1.<arch>.rpm` | `sudo dnf install ./creator-toolkit-<version>-1.<arch>.rpm` |
| openSUSE Tumbleweed | `creator-toolkit-<version>-1.<arch>.rpm` | `sudo zypper install --allow-unsigned-rpm ./creator-toolkit-<version>-1.<arch>.rpm` |
| Arch, Manjaro, EndeavourOS | `creator-toolkit-<version>-1-<arch>.pkg.tar.zst` | `sudo pacman -U ./creator-toolkit-<version>-1-<arch>.pkg.tar.zst` |
| Any (AppImage) | `CreatorToolkit-<version>-<arch>.AppImage` | `chmod +x CreatorToolkit-<version>-<arch>.AppImage && ./CreatorToolkit-<version>-<arch>.AppImage` |
| Any (Flatpak) | `creator-toolkit-<version>-<arch>.flatpak` | `flatpak install --user ./creator-toolkit-<version>-<arch>.flatpak` |

- The binaries are built on Ubuntu 24.04, so they need glibc 2.39 or newer:
  Fedora 40+, openSUSE Tumbleweed and current Arch, but not openSUSE Leap 15
  or RHEL 9. The AppImage uses the system's GTK 3 and ffmpeg.
- **ffmpeg:** the `.rpm` pulls in the distribution's ffmpeg as a weak
  dependency, and on Arch it is an optional dependency (`sudo pacman -S
  ffmpeg`). Fedora's own `ffmpeg-free` and openSUSE's `ffmpeg` leave out the
  patent-encumbered H.264 encoder (libx264) that video compression and
  MP4/MKV/MOV output use; install the full ffmpeg from RPM Fusion (Fedora)
  or Packman (openSUSE) for those. Arch's ffmpeg includes it.
- The **Flatpak** includes its own ffmpeg with every codec the app uses, so it
  needs nothing else. It uses the GNOME 51 runtime from Flathub: add the
  Flathub remote first (`flatpak remote-add --user --if-not-exists flathub
  https://dl.flathub.org/repo/flathub.flatpakrepo`). It opens files through
  the file chooser (or drag and drop) and writes only to `~/CreatorToolkit`.
- The `.rpm` files are unsigned (hence `--allow-unsigned-rpm` on openSUSE).
- Arch users can build `creator-toolkit-bin` from the AUR recipe attached to
  each release (`creator-toolkit-bin-<version>-aur.tar.gz`: PKGBUILD,
  .SRCINFO, desktop entry and icons).

## Build

```bash
flutter pub get
flutter build linux --release    # Linux
flutter build windows --release  # on a Windows machine
flutter build apk --release      # Android
flutter test                     # service + widget tests
```

Flutter cannot cross-compile desktop apps: an arm64 build is made on an arm64
machine (`build/linux/arm64/...`, `build\windows\arm64\...`) with the same
commands. The **Desktop builds** workflow (`.github/workflows/desktop.yml`)
does that on native runners for Linux x64, Linux arm64, Windows x64 and
Windows arm64: tests, release build, packaging (`tool/build_tarball.sh`,
`tool/package_windows.ps1`) and a start-up check of the built app. The Linux
packages (`packaging/`) are installed and run too: the `.rpm` on Fedora and
openSUSE Tumbleweed, the Arch package on Arch Linux (x64; arm64 gets a static
check, as there is no official Arch Linux ARM image), the AppImage on Fedora,
and the Flatpak in its sandbox, where the bundled ffmpeg also runs every
encoding the app uses.

## Architecture notes

- **Riverpod** for theme mode and the global job list (`lib/providers/`).
- `lib/services/` holds all processing logic, UI-free and covered by
  `test/services_test.dart`:
  - `FfmpegService` — system binary on desktop, ffmpeg-kit on Android,
    with unified progress parsing.
  - `ImageService` — pure-Dart `image` package in background isolates;
    Android uses `flutter_image_compress` for fast native JPG/WEBP encodes.
  - `PdfService` — Syncfusion PDF (pure Dart) in background isolates.
- `ffmpeg_kit_flutter_new` is only used on Android. Its Windows plugin
  downloads prebuilt x86_64 DLLs (none exist for arm64) and its CMake cannot
  unpack them on CI runners, so the CI-built Windows packages are made
  without that plugin (`tool/strip_ffmpeg_kit_windows.ps1`); the desktop code
  never called it. A plain local `flutter build windows` still includes it.
- `file_picker` is pinned to 10.x: 11.x skips applying its own Kotlin plugin
  under AGP 9 while the Flutter 3.44 template sets
  `android.builtInKotlin=false`, which leaves its classes uncompiled.

## Sponsors

Dhiva Labs is an independent, self-funded lab. [Sponsorships](https://github.com/sponsors/Dhiva-Labs) help bring this project and the rest of Dhiva Labs to every platform, iPhone and Mac included.

[![Sponsor Dhiva Labs](https://img.shields.io/badge/Sponsor-Dhiva%20Labs-ea4aaa?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/Dhiva-Labs)

Monthly sponsors at $10 and up are listed here:

<!-- sponsors -->
*Be the first: [sponsor Dhiva Labs](https://github.com/sponsors/Dhiva-Labs).*
<!-- sponsors -->
