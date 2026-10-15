# Creator Toolkit

[![ARM64 builds](https://github.com/Dhiva-Labs/creator_toolkit/actions/workflows/desktop.yml/badge.svg?branch=main)](https://github.com/Dhiva-Labs/creator_toolkit/actions/workflows/desktop.yml)
![Linux x64 | arm64](https://img.shields.io/badge/Linux-x64%20%7C%20arm64-informational?logo=linux&logoColor=white)
![Windows x64 | arm64](https://img.shields.io/badge/Windows-x64%20%7C%20arm64-informational?logo=windows&logoColor=white)

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

GitHub releases published after the CI workflow was added carry the desktop
builds, and every CI run keeps them as workflow artifacts:

| Platform      | File                                          |
|---------------|-----------------------------------------------|
| Linux x64     | `CreatorToolkit-<version>-linux-x64.tar.gz`   |
| Linux arm64   | `CreatorToolkit-<version>-linux-arm64.tar.gz` |
| Windows x64   | `CreatorToolkit-<version>-windows-x64.zip`    |
| Windows arm64 | `CreatorToolkit-<version>-windows-arm64.zip`  |

Unpack and run `creator_toolkit` (`creator_toolkit.exe` on Windows). The video
and audio tools need `ffmpeg` on PATH (Windows: for example
`winget install Gyan.FFmpeg`).

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
`tool/package_windows.ps1`) and a start-up check of the built app.

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
