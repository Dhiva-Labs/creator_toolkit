# Creator Toolkit

A simple, modern Flutter app that helps content creators optimize and convert
media before sharing it online. Runs on **Linux, Windows, and Android** from a
single codebase, fully offline.

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

## Build

```bash
flutter pub get
flutter build linux --release    # Linux
flutter build windows --release  # on a Windows machine
flutter build apk --release      # Android
flutter test                     # service + widget tests
```

## Architecture notes

- **Riverpod** for theme mode and the global job list (`lib/providers/`).
- `lib/services/` holds all processing logic, UI-free and covered by
  `test/services_test.dart`:
  - `FfmpegService` — system binary on desktop, ffmpeg-kit on Android,
    with unified progress parsing.
  - `ImageService` — pure-Dart `image` package in background isolates;
    Android uses `flutter_image_compress` for fast native JPG/WEBP encodes.
  - `PdfService` — Syncfusion PDF (pure Dart) in background isolates.
- `file_picker` is pinned to 10.x: 11.x skips applying its own Kotlin plugin
  under AGP 9 while the Flutter 3.44 template sets
  `android.builtInKotlin=false`, which leaves its classes uncompiled.
