<#
.SYNOPSIS
Builds the Windows app without the ffmpeg_kit_flutter_new Windows plugin.

.DESCRIPTION
Run from anywhere after `flutter pub get`, before `flutter test` and
`flutter build windows`:

    pwsh tool/strip_ffmpeg_kit_windows.ps1

Why: ffmpeg_kit_flutter_new is the Android FFmpeg (lib/services/ffmpeg_service.dart
only calls it when Platform.isAndroid; on desktop the app runs the system
ffmpeg). The package also declares a Windows plugin whose CMake downloads
prebuilt x86_64 DLLs. That download

  * has no arm64 counterpart, so a Windows arm64 build cannot get past it, and
  * fails on the GitHub runners on x64 as well: CMake refuses to extract the
    archive "through symlink" .plugin_symlinks\ffmpeg_kit_flutter_new.

Nothing on Windows ever calls the plugin, so this script copies the package
from the pub cache to a temporary folder, drops its windows\ folder and its
`windows:` platform entry, and points the build at that copy through an
untracked pubspec_overrides.yaml. The Dart API is unchanged, pubspec.yaml and
pubspec.lock stay as committed, and Android builds are not affected.
#>
param(
    [string]$Work = (Join-Path ([IO.Path]::GetTempPath()) 'ffmpeg_kit_flutter_new_no_windows')
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Set-Location (Join-Path $PSScriptRoot '..')

$config = Get-Content '.dart_tool/package_config.json' -Raw | ConvertFrom-Json
$package = $config.packages | Where-Object { $_.name -eq 'ffmpeg_kit_flutter_new' } | Select-Object -First 1
if (-not $package) { throw 'ffmpeg_kit_flutter_new is not in .dart_tool/package_config.json - run flutter pub get first' }
$source = ([Uri]::new([Uri]((Resolve-Path '.dart_tool').Path + '\'), $package.rootUri)).LocalPath
if (-not (Test-Path (Join-Path $source 'pubspec.yaml'))) { throw "no pubspec.yaml in $source" }

if (Test-Path $Work) { Remove-Item -Recurse -Force $Work }
Copy-Item -Recurse -Path $source -Destination $Work
Remove-Item -Recurse -Force (Join-Path $Work 'windows')

$pubspecPath = Join-Path $Work 'pubspec.yaml'
$pubspec = Get-Content $pubspecPath -Raw
$stripped = $pubspec -replace '(?m)^      windows:\r?\n        pluginClass: FFmpegKitFlutterPlugin\r?\n', ''
if ($stripped -eq $pubspec -or $stripped -match '(?m)^\s+windows:') {
    throw "could not remove the windows: platform entry from $pubspecPath"
}
Set-Content -Path $pubspecPath -Value $stripped -NoNewline

$workPath = $Work -replace '\\', '/'
Set-Content -Path 'pubspec_overrides.yaml' -Value "dependency_overrides:`n  ffmpeg_kit_flutter_new:`n    path: $workPath`n"
Write-Host "ffmpeg_kit_flutter_new now comes from $Work without its Windows plugin"
flutter pub get
if ((Get-Content 'windows/flutter/generated_plugins.cmake' -Raw) -match 'ffmpeg_kit') {
    throw 'windows/flutter/generated_plugins.cmake still lists ffmpeg_kit_flutter_new'
}
Write-Host 'windows/flutter/generated_plugins.cmake no longer lists ffmpeg_kit_flutter_new'
