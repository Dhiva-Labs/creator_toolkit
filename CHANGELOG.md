# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-16

First release. `pubspec.yaml` already said 1.0.0+1; the repo had no tags or
releases before this one.

### Added
- Creator Toolkit: a fully offline app that optimizes and converts media before
  sharing: image tools (compress, resize, crop, convert), video tools
  (compress, convert, trim), audio tools (compress, convert), PDF tools
  (compress, merge, split) and one-click social media presets.
- Linux x64, Linux arm64, Windows x64 and Windows arm64 builds. Every package
  is built, tested and started on a runner of its own architecture. Releases
  carry `CreatorToolkit-<version>-linux-x64.tar.gz`,
  `CreatorToolkit-<version>-linux-arm64.tar.gz`,
  `CreatorToolkit-<version>-windows-x64.zip` and
  `CreatorToolkit-<version>-windows-arm64.zip`.
- Releases are completed by CI: publishing a release attaches the desktop
  packages, leaving alone any file name already on the release.

### Changed
- `jni` is updated to 1.0.3, which compiles on Linux arm64.

### Notes
- The CI-built Windows packages are made without the `ffmpeg_kit_flutter_new`
  Windows plugin (it downloads x86_64-only DLLs); the desktop code never called
  it. Video and audio tools use the `ffmpeg` on PATH.
- The Android APK is not built by CI and is not part of this release.
